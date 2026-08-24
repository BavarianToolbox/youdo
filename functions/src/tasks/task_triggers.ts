import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY ?? "", {
  apiVersion: "2024-06-20",
});

/**
 * Auto-creates a Stripe Customer when a new user document is created.
 * Writes stripeCustomerId back to the user document.
 */
export const createStripeCustomer = onDocumentCreated(
  "users/{userId}",
  async (event) => {
    const userId = event.params.userId;
    const data = event.data?.data();
    if (!data) return;

    try {
      const customer = await stripe.customers.create({
        email: data.email as string,
        name: data.displayName as string,
        metadata: { firebaseUid: userId },
      });

      await admin.firestore().collection("users").doc(userId).update({
        stripeCustomerId: customer.id,
      });

      console.log(`Created Stripe customer ${customer.id} for user ${userId}`);
    } catch (error) {
      console.error(`Failed to create Stripe customer for user ${userId}:`, error);
    }
  }
);
