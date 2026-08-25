import { PaymentIntentEvent, WebhookService, WebhookStore } from "../_shared/webhook_service.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

class FakeWebhookStore implements WebhookStore {
  events: PaymentIntentEvent[] = [];
  applyPaymentIntentEvent(event: PaymentIntentEvent): Promise<void> {
    this.events.push(event);
    return Promise.resolve();
  }
}

Deno.test("successful PaymentIntent events update the transaction", async () => {
  const store = new FakeWebhookStore();
  const result = await new WebhookService(store).handle({
    id: "evt_1",
    type: "payment_intent.succeeded",
    data: { object: { id: "pi_1" } },
  });
  assertEquals(result, { received: true, handled: true });
  assertEquals(store.events, [{
    eventId: "evt_1",
    eventType: "payment_intent.succeeded",
    paymentIntentId: "pi_1",
  }]);
});

Deno.test("failed PaymentIntent events update the transaction", async () => {
  const store = new FakeWebhookStore();
  await new WebhookService(store).handle({
    id: "evt_2",
    type: "payment_intent.payment_failed",
    data: { object: { id: "pi_2" } },
  });
  assertEquals(store.events[0].eventType, "payment_intent.payment_failed");
});

Deno.test("unrelated Stripe events are acknowledged without database writes", async () => {
  const store = new FakeWebhookStore();
  const result = await new WebhookService(store).handle({
    id: "evt_3",
    type: "customer.updated",
    data: { object: { id: "cus_1" } },
  });
  assertEquals(result, { received: true, handled: false });
  assertEquals(store.events, []);
});
