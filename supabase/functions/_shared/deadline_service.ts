import { ProfileRecord, StripeGateway, TaskRecord } from "./payment_service.ts";

export interface DeadlineStore {
  claimOverdueTasks(limit: number): Promise<TaskRecord[]>;
  getProfile(userId: string): Promise<ProfileRecord | null>;
  hasPenaltyTransaction(taskId: string): Promise<boolean>;
  recordPenalty(
    userId: string,
    task: TaskRecord,
    paymentIntentId: string,
    status: "pending" | "succeeded" | "failed",
  ): Promise<void>;
}

export class DeadlineService {
  constructor(
    private readonly store: DeadlineStore,
    private readonly stripe: StripeGateway,
  ) {}

  async process(
    limit = 100,
  ): Promise<{ claimed: number; charged: number; skipped: number; failed: number }> {
    const tasks = await this.store.claimOverdueTasks(limit);
    let charged = 0;
    let skipped = 0;
    let failed = 0;
    for (const task of tasks) {
      try {
        if (task.penaltyAmount <= 0 || await this.store.hasPenaltyTransaction(task.id)) {
          skipped++;
          continue;
        }
        const profile = await this.store.getProfile(task.userId);
        if (profile?.stripeCustomerId == null || profile.stripePaymentMethodId == null) {
          skipped++;
          continue;
        }
        const intent = await this.stripe.chargePenalty({
          customerId: profile.stripeCustomerId,
          paymentMethodId: profile.stripePaymentMethodId,
          amountInCents: Math.round(task.penaltyAmount * 100),
          taskId: task.id,
          userId: task.userId,
          description: `You-Do missed task penalty: ${task.title}`,
        });
        await this.store.recordPenalty(
          task.userId,
          task,
          intent.id,
          intent.status === "succeeded" ? "succeeded" : "pending",
        );
        charged++;
      } catch (error) {
        console.error(`Failed to process overdue task ${task.id}`, error);
        failed++;
      }
    }
    return { claimed: tasks.length, charged, skipped, failed };
  }
}
