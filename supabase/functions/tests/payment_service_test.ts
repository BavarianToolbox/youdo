import {
  ApiError,
  PaymentService,
  PaymentStore,
  ProfileRecord,
  StripeGateway,
  TaskRecord,
  TransactionRecord,
} from "../_shared/payment_service.ts";

function assert(condition: unknown, message = "assertion failed"): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown): void {
  const left = JSON.stringify(actual);
  const right = JSON.stringify(expected);
  if (left !== right) throw new Error(`expected ${right}, got ${left}`);
}

class FakeStore implements PaymentStore {
  profile: ProfileRecord | null = {
    id: "user-1",
    email: "dev@example.com",
    displayName: "Dev",
    stripeCustomerId: null,
    stripePaymentMethodId: null,
  };
  task: TaskRecord | null = null;
  transaction: TransactionRecord | null = null;
  rewards = 0;
  penalties = 0;

  getProfile(): Promise<ProfileRecord | null> {
    return Promise.resolve(this.profile);
  }
  setStripeCustomer(_userId: string, customerId: string): Promise<void> {
    this.profile = { ...this.profile!, stripeCustomerId: customerId };
    return Promise.resolve();
  }
  setPaymentMethod(_userId: string, paymentMethodId: string): Promise<void> {
    this.profile = { ...this.profile!, stripePaymentMethodId: paymentMethodId };
    return Promise.resolve();
  }
  completeTask(): Promise<TaskRecord | null> {
    return Promise.resolve(this.task);
  }
  getTaskTransaction(): Promise<TransactionRecord | null> {
    return Promise.resolve(this.transaction);
  }
  applyReward(): Promise<void> {
    this.rewards++;
    return Promise.resolve();
  }
  recordPenalty(): Promise<void> {
    this.penalties++;
    return Promise.resolve();
  }
}

class FakeStripe implements StripeGateway {
  customers = 0;
  charges = 0;
  createCustomer(): Promise<string> {
    this.customers++;
    return Promise.resolve("cus_1");
  }
  createSetupIntent(): Promise<{ clientSecret: string }> {
    return Promise.resolve({ clientSecret: "seti_secret" });
  }
  attachPaymentMethod(): Promise<void> {
    return Promise.resolve();
  }
  chargePenalty(): Promise<{ id: string; status: string }> {
    this.charges++;
    return Promise.resolve({ id: "pi_1", status: "succeeded" });
  }
}

function completedTask(isOnTime: boolean): TaskRecord {
  return {
    id: "task-1",
    userId: "user-1",
    title: "Finish",
    dueDate: "2026-08-24T12:00:00Z",
    completedAt: isOnTime ? "2026-08-24T11:59:00Z" : "2026-08-24T12:01:00Z",
    status: isOnTime ? "completed_on_time" : "completed_late",
    rewardAmount: 10,
    penaltyAmount: 5,
  };
}

Deno.test("createSetupIntent creates and persists a missing Stripe customer", async () => {
  const store = new FakeStore();
  const stripe = new FakeStripe();
  const result = await new PaymentService(store, stripe).createSetupIntent("user-1");
  assertEquals(result, { clientSecret: "seti_secret" });
  assertEquals(stripe.customers, 1);
  assertEquals(store.profile?.stripeCustomerId, "cus_1");
});

Deno.test("savePaymentMethod rejects malformed identifiers", async () => {
  const service = new PaymentService(new FakeStore(), new FakeStripe());
  try {
    await service.savePaymentMethod("user-1", "card_unsafe");
    throw new Error("expected rejection");
  } catch (error) {
    assert(error instanceof ApiError);
    assertEquals(error.status, 400);
  }
});

Deno.test("on-time completion applies a reward", async () => {
  const store = new FakeStore();
  store.task = completedTask(true);
  const result = await new PaymentService(store, new FakeStripe())
    .processTaskCompletion("user-1", "task-1");
  assertEquals(store.rewards, 1);
  assertEquals(result.credited, 10);
});

Deno.test("completion timing is derived from persisted timestamps", async () => {
  const store = new FakeStore();
  store.task = { ...completedTask(false), status: "completed_on_time" };
  store.profile = {
    ...store.profile!,
    stripeCustomerId: "cus_1",
    stripePaymentMethodId: "pm_1",
  };
  const stripe = new FakeStripe();
  await new PaymentService(store, stripe).processTaskCompletion("user-1", "task-1");
  assertEquals(stripe.charges, 1);
  assertEquals(store.rewards, 0);
});

Deno.test("late completion charges and records a penalty", async () => {
  const store = new FakeStore();
  store.task = completedTask(false);
  store.profile = {
    ...store.profile!,
    stripeCustomerId: "cus_1",
    stripePaymentMethodId: "pm_1",
  };
  const stripe = new FakeStripe();
  const result = await new PaymentService(store, stripe)
    .processTaskCompletion("user-1", "task-1");
  assertEquals(stripe.charges, 1);
  assertEquals(store.penalties, 1);
  assertEquals(result.charged, 5);
});

Deno.test("an existing penalty makes completion retry idempotent", async () => {
  const store = new FakeStore();
  store.task = completedTask(false);
  store.transaction = { type: "penalty", amount: 5, status: "succeeded" };
  const stripe = new FakeStripe();
  await new PaymentService(store, stripe).processTaskCompletion("user-1", "task-1");
  assertEquals(stripe.charges, 0);
  assertEquals(store.penalties, 0);
});
