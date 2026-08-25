import Stripe from "npm:stripe@16.12.0";

import { createAdminClient, createStripeClient, requiredEnv } from "../_shared/runtime.ts";
import { PaymentIntentEvent, WebhookService, WebhookStore } from "../_shared/webhook_service.ts";

class SupabaseWebhookStore implements WebhookStore {
  constructor(private readonly admin: ReturnType<typeof createAdminClient>) {}

  async applyPaymentIntentEvent(event: PaymentIntentEvent): Promise<void> {
    const { error } = await this.admin.rpc("apply_payment_intent_event", {
      p_event_id: event.eventId,
      p_event_type: event.eventType,
      p_stripe_intent_id: event.paymentIntentId,
      p_status: event.eventType === "payment_intent.succeeded" ? "succeeded" : "failed",
    });
    if (error) throw error;
  }
}

const stripe = createStripeClient();
const service = new WebhookService(new SupabaseWebhookStore(createAdminClient()));
const cryptoProvider = Stripe.createSubtleCryptoProvider();

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const signature = request.headers.get("stripe-signature");
  if (signature == null) return new Response("Missing Stripe signature", { status: 400 });
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      await request.text(),
      signature,
      requiredEnv("STRIPE_WEBHOOK_SECRET"),
      undefined,
      cryptoProvider,
    );
  } catch (error) {
    console.error(error);
    return new Response("Invalid Stripe webhook", { status: 400 });
  }
  try {
    return Response.json(await service.handle(event));
  } catch (error) {
    console.error(error);
    return new Response("Webhook processing failed", { status: 500 });
  }
});
