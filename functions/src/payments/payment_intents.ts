import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import Stripe from "stripe";
import { v4 as uuidv4 } from "uuid";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY ?? "", {
  apiVersion: "2024-06-20",
});

/**
 * Creates a Stripe SetupIntent so the Flutter app can collect a card
 * on-device without raw card data passing through our server.
 */
export const createSetupIntent = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");

  const uid = request.auth.uid;
  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  const userData = userDoc.data();

  if (!userData?.stripeCustomerId) {
    throw new HttpsError("failed-precondition", "Stripe customer not set up yet");
  }

  const setupIntent = await stripe.setupIntents.create({
    customer: userData.stripeCustomerId as string,
    payment_method_types: ["card"],
    usage: "off_session",
  });

  return { clientSecret: setupIntent.client_secret };
});

/**
 * After Stripe confirms the SetupIntent on-device, the app sends the
 * payment method ID here to attach it to the customer and update Firestore.
 */
export const savePaymentMethod = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");

  const uid = request.auth.uid;
  const { paymentMethodId } = request.data as { paymentMethodId: string };

  if (!paymentMethodId) {
    throw new HttpsError("invalid-argument", "paymentMethodId is required");
  }

  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  const userData = userDoc.data();

  if (!userData?.stripeCustomerId) {
    throw new HttpsError("failed-precondition", "Stripe customer not set up");
  }

  const customerId = userData.stripeCustomerId as string;

  // Attach to customer
  await stripe.paymentMethods.attach(paymentMethodId, { customer: customerId });

  // Set as default payment method
  await stripe.customers.update(customerId, {
    invoice_settings: { default_payment_method: paymentMethodId },
  });

  // Update Firestore
  await admin.firestore().collection("users").doc(uid).update({
    stripePaymentMethodId: paymentMethodId,
    hasPaymentMethod: true,
  });

  return { success: true };
});

/**
 * Called by the Flutter app when a user marks a task complete.
 * Evaluates on-time vs late, charges penalty or credits reward.
 */
export const processTaskCompletion = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");

  const uid = request.auth.uid;
  const { taskId, isOnTime } = request.data as {
    taskId: string;
    isOnTime: boolean;
  };

  if (!taskId) throw new HttpsError("invalid-argument", "taskId is required");

  const db = admin.firestore();
  const taskDoc = await db.collection("tasks").doc(taskId).get();
  const task = taskDoc.data();

  if (!task || task.userId !== uid) {
    throw new HttpsError("not-found", "Task not found");
  }

  const userDoc = await db.collection("users").doc(uid).get();
  const user = userDoc.data();

  const results: { message: string; charged?: number; credited?: number } = {
    message: isOnTime ? "Task completed on time!" : "Task completed late.",
  };

  if (isOnTime && task.rewardAmount > 0) {
    // MVP: credit reward as YD balance (Stripe Connect payouts in Phase 2)
    const newBalance = (user?.ydBalance ?? 0) + task.rewardAmount;
    await db.collection("users").doc(uid).update({ ydBalance: newBalance });

    await _writeTransaction(db, uid, taskId, task.title, "reward", task.rewardAmount);
    await db.collection("users").doc(uid).update({
      totalEarned: admin.firestore.FieldValue.increment(task.rewardAmount),
    });

    results.credited = task.rewardAmount;
    results.message = `Reward of $${task.rewardAmount.toFixed(2)} credited!`;
  } else if (!isOnTime && task.penaltyAmount > 0 && user?.stripePaymentMethodId) {
    // Charge penalty
    const paymentIntent = await _chargeCustomer({
      customerId: user.stripeCustomerId as string,
      paymentMethodId: user.stripePaymentMethodId as string,
      amount: task.penaltyAmount,
      taskId,
      userId: uid,
      description: `You-Do penalty: ${task.title}`,
    });

    await _writeTransaction(
      db, uid, taskId, task.title, "penalty", task.penaltyAmount,
      paymentIntent.id
    );
    await db.collection("users").doc(uid).update({
      totalLost: admin.firestore.FieldValue.increment(task.penaltyAmount),
    });

    results.charged = task.penaltyAmount;
    results.message = `Penalty of $${task.penaltyAmount.toFixed(2)} charged.`;
  }

  return results;
});

async function _chargeCustomer({
  customerId,
  paymentMethodId,
  amount,
  taskId,
  userId,
  description,
}: {
  customerId: string;
  paymentMethodId: string;
  amount: number;
  taskId: string;
  userId: string;
  description: string;
}) {
  return stripe.paymentIntents.create({
    amount: Math.round(amount * 100), // Stripe uses cents
    currency: "usd",
    customer: customerId,
    payment_method: paymentMethodId,
    confirm: true,
    off_session: true,
    description,
    metadata: { taskId, userId },
  });
}

async function _writeTransaction(
  db: admin.firestore.Firestore,
  userId: string,
  taskId: string,
  taskTitle: string,
  type: "reward" | "penalty",
  amount: number,
  stripeIntentId?: string
) {
  await db.collection("transactions").doc(uuidv4()).set({
    userId,
    taskId,
    taskTitle,
    type,
    amount,
    status: "succeeded",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(stripeIntentId ? { stripeIntentId } : {}),
  });
}
