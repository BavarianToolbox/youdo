export interface PaymentIntentEvent {
  eventId: string;
  eventType: "payment_intent.succeeded" | "payment_intent.payment_failed";
  paymentIntentId: string;
}

export interface WebhookStore {
  applyPaymentIntentEvent(event: PaymentIntentEvent): Promise<void>;
}

export class WebhookService {
  constructor(private readonly store: WebhookStore) {}

  async handle(event: {
    id: string;
    type: string;
    data: { object: unknown };
  }): Promise<{ received: true; handled: boolean }> {
    if (
      event.type !== "payment_intent.succeeded" &&
      event.type !== "payment_intent.payment_failed"
    ) {
      return { received: true, handled: false };
    }
    const paymentIntentId = (event.data.object as { id?: string }).id;
    if (paymentIntentId == null) throw new Error("PaymentIntent event is missing its object ID");
    await this.store.applyPaymentIntentEvent({
      eventId: event.id,
      eventType: event.type,
      paymentIntentId,
    });
    return { received: true, handled: true };
  }
}
