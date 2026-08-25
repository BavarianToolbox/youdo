import { DeadlineService, DeadlineStore } from "../_shared/deadline_service.ts";
import { ProfileRecord, StripeGateway, TaskRecord } from "../_shared/payment_service.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

const task: TaskRecord = {
  id: "task-1",
  userId: "user-1",
  title: "Missed task",
  dueDate: "2026-08-24T12:00:00Z",
  completedAt: null,
  status: "missed",
  rewardAmount: 0,
  penaltyAmount: 5,
};

class FakeDeadlineStore implements DeadlineStore {
  tasks: TaskRecord[] = [task];
  existing = false;
  recorded = 0;
  profile: ProfileRecord | null = {
    id: "user-1",
    email: "dev@example.com",
    displayName: "Dev",
    stripeCustomerId: "cus_1",
    stripePaymentMethodId: "pm_1",
  };
  claimOverdueTasks(): Promise<TaskRecord[]> {
    return Promise.resolve(this.tasks);
  }
  getProfile(): Promise<ProfileRecord | null> {
    return Promise.resolve(this.profile);
  }
  hasPenaltyTransaction(): Promise<boolean> {
    return Promise.resolve(this.existing);
  }
  recordPenalty(): Promise<void> {
    this.recorded++;
    return Promise.resolve();
  }
}

class FakeStripe implements StripeGateway {
  charges = 0;
  createCustomer(): Promise<string> {
    throw new Error("unused");
  }
  createSetupIntent(): Promise<{ clientSecret: string }> {
    throw new Error("unused");
  }
  attachPaymentMethod(): Promise<void> {
    throw new Error("unused");
  }
  chargePenalty(): Promise<{ id: string; status: string }> {
    this.charges++;
    return Promise.resolve({ id: "pi_1", status: "succeeded" });
  }
}

Deno.test("overdue tasks with payment methods are charged and recorded", async () => {
  const store = new FakeDeadlineStore();
  const stripe = new FakeStripe();
  const result = await new DeadlineService(store, stripe).process();
  assertEquals(result, { claimed: 1, charged: 1, skipped: 0, failed: 0 });
  assertEquals(stripe.charges, 1);
  assertEquals(store.recorded, 1);
});

Deno.test("tasks with an existing penalty are skipped", async () => {
  const store = new FakeDeadlineStore();
  store.existing = true;
  const stripe = new FakeStripe();
  const result = await new DeadlineService(store, stripe).process();
  assertEquals(result, { claimed: 1, charged: 0, skipped: 1, failed: 0 });
  assertEquals(stripe.charges, 0);
});

Deno.test("tasks without a saved payment method are skipped", async () => {
  const store = new FakeDeadlineStore();
  store.profile = { ...store.profile!, stripePaymentMethodId: null };
  const result = await new DeadlineService(store, new FakeStripe()).process();
  assertEquals(result, { claimed: 1, charged: 0, skipped: 1, failed: 0 });
});
