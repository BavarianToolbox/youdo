import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import Stripe from "stripe";
import { v4 as uuidv4 } from "uuid";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY ?? "", {
  apiVersion: "2024-06-20",
});

/**
 * Runs every 15 minutes. Finds pending tasks past their deadline,
 * marks them missed, and charges penalties idempotently.
 */
export const checkDeadlines = onSchedule("every 15 minutes", async () => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  const snap = await db
    .collection("tasks")
    .where("status", "==", "pending")
    .where("dueDate", "<", now)
    .where("deadlineProcessed", "==", false)
    .limit(500)
    .get();

  if (snap.empty) {
    console.log("checkDeadlines: no overdue tasks found");
    return;
  }

  console.log(`checkDeadlines: processing ${snap.size} overdue tasks`);

  const batch = db.batch();

  for (const doc of snap.docs) {
    // Idempotency: mark deadlineProcessed=true atomically first
    batch.update(doc.ref, {
      status: "missed",
      deadlineProcessed: true,
    });

    // Commit the status update immediately to prevent double-processing
    // We'll handle payment separately below
  }

  await batch.commit();

  // Now handle payments and notifications (outside batch for error isolation)
  for (const doc of snap.docs) {
    const task = doc.data();
    const userId = task.userId as string;

    try {
      if (task.penaltyAmount > 0) {
        const userDoc = await db.collection("users").doc(userId).get();
        const user = userDoc.data();

        if (user?.hasPaymentMethod && user?.stripePaymentMethodId) {
          const pi = await stripe.paymentIntents.create({
            amount: Math.round((task.penaltyAmount as number) * 100),
            currency: "usd",
            customer: user.stripeCustomerId as string,
            payment_method: user.stripePaymentMethodId as string,
            confirm: true,
            off_session: true,
            description: `You-Do missed task penalty: ${task.title}`,
            metadata: { taskId: doc.id, userId },
          });

          await db.collection("transactions").doc(uuidv4()).set({
            userId,
            taskId: doc.id,
            taskTitle: task.title,
            type: "penalty",
            amount: task.penaltyAmount,
            status: pi.status === "succeeded" ? "succeeded" : "pending",
            stripeIntentId: pi.id,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          if (pi.status === "succeeded") {
            await db.collection("users").doc(userId).update({
              totalLost: admin.firestore.FieldValue.increment(task.penaltyAmount),
            });
          }
        }
      }

      // Send FCM push notification
      await _notifyTaskMissed(db, userId, task.title as string, task.penaltyAmount as number);
    } catch (error) {
      console.error(`Failed to process missed task ${doc.id}:`, error);
      // Don't re-throw — continue processing other tasks
    }
  }
});

/**
 * Runs every 60 minutes. Sends reminders for tasks due within the next 65 minutes.
 */
export const sendDeadlineReminders = onSchedule("every 60 minutes", async () => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const inSixtyFiveMinutes = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 65 * 60 * 1000)
  );

  const snap = await db
    .collection("tasks")
    .where("status", "==", "pending")
    .where("dueDate", ">", now)
    .where("dueDate", "<=", inSixtyFiveMinutes)
    .where("notificationScheduled", "==", false)
    .limit(500)
    .get();

  if (snap.empty) return;

  console.log(`sendDeadlineReminders: sending ${snap.size} reminders`);

  for (const doc of snap.docs) {
    const task = doc.data();
    const userId = task.userId as string;

    try {
      await _notifyTaskApproaching(db, userId, task.title as string, task.penaltyAmount as number);
      await doc.ref.update({ notificationScheduled: true });
    } catch (error) {
      console.error(`Failed to send reminder for task ${doc.id}:`, error);
    }
  }
});

async function _notifyTaskMissed(
  db: admin.firestore.Firestore,
  userId: string,
  taskTitle: string,
  penaltyAmount: number
) {
  const userDoc = await db.collection("users").doc(userId).get();
  const fcmToken = userDoc.data()?.fcmToken as string | undefined;
  if (!fcmToken) return;

  const body = penaltyAmount > 0
    ? `$${penaltyAmount.toFixed(2)} penalty applied for missing: ${taskTitle}`
    : `You missed your task: ${taskTitle}`;

  await admin.messaging().send({
    token: fcmToken,
    notification: { title: "Task missed", body },
  });
}

async function _notifyTaskApproaching(
  db: admin.firestore.Firestore,
  userId: string,
  taskTitle: string,
  penaltyAmount: number
) {
  const userDoc = await db.collection("users").doc(userId).get();
  const fcmToken = userDoc.data()?.fcmToken as string | undefined;
  if (!fcmToken) return;

  const body = penaltyAmount > 0
    ? `Don't lose $${penaltyAmount.toFixed(2)}! Complete: ${taskTitle}`
    : `Due in about 1 hour: ${taskTitle}`;

  await admin.messaging().send({
    token: fcmToken,
    notification: { title: "⏰ Task due soon", body },
  });
}
