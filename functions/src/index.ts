import * as admin from "firebase-admin";

admin.initializeApp();

export { createStripeCustomer } from "./tasks/task_triggers";
export { createSetupIntent, savePaymentMethod, processTaskCompletion } from "./payments/payment_intents";
export { stripeWebhook } from "./payments/stripe_webhooks";
export { checkDeadlines, sendDeadlineReminders } from "./tasks/deadline_checker";
