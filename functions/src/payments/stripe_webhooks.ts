import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY ?? "", {
  apiVersion: "2024-06-20",
});

/**
 * Stripe webhook endpoint. Register this URL in the Stripe dashboard:
 * https://dashboard.stripe.com/webhooks
 *
 * Events handled:
 * - payment_intent.succeeded → update transaction status to 'succeeded'
 * - payment_intent.payment_failed → update transaction status to 'failed', notify user
 */
export const stripeWebhook = onRequest(async (req, res) => {
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET ?? "";
  const sig = req.headers["stripe-signature"];

  if (!sig) {
    res.status(400).send("Missing stripe-signature header");
    return;
  }

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(
      req.rawBody,
      sig,
      webhookSecret
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    res.status(400).send("Webhook signature verification failed");
    return;
  }

  const db = admin.firestore();

  switch (event.type) {
    case "payment_intent.succeeded": {
      const pi = event.data.object as Stripe.PaymentIntent;
      await _updateTransactionByStripeId(db, pi.id, "succeeded");
      console.log(`PaymentIntent ${pi.id} succeeded`);
      break;
    }

    case "payment_intent.payment_failed": {
      const pi = event.data.object as Stripe.PaymentIntent;
      await _updateTransactionByStripeId(db, pi.id, "failed");

      // Notify user via FCM
      const userId = pi.metadata?.userId;
      if (userId) {
        await _notifyUserPaymentFailed(db, userId, pi.amount / 100);
      }

      console.log(`PaymentIntent ${pi.id} failed`);
      break;
    }

    default:
      console.log(`Unhandled event type: ${event.type}`);
  }

  res.status(200).send("OK");
});

async function _updateTransactionByStripeId(
  db: admin.firestore.Firestore,
  stripeIntentId: string,
  status: "succeeded" | "failed"
) {
  const snap = await db
    .collection("transactions")
    .where("stripeIntentId", "==", stripeIntentId)
    .limit(1)
    .get();

  if (snap.empty) {
    console.warn(`No transaction found for stripeIntentId: ${stripeIntentId}`);
    return;
  }

  await snap.docs[0].ref.update({ status });
}

async function _notifyUserPaymentFailed(
  db: admin.firestore.Firestore,
  userId: string,
  amount: number
) {
  const userDoc = await db.collection("users").doc(userId).get();
  const fcmToken = userDoc.data()?.fcmToken as string | undefined;

  if (!fcmToken) return;

  await admin.messaging().send({
    token: fcmToken,
    notification: {
      title: "Payment failed",
      body: `A penalty charge of $${amount.toFixed(2)} could not be processed. Update your payment method.`,
    },
  });
}
