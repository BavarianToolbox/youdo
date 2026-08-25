export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export interface ProfileRecord {
  id: string;
  email: string;
  displayName: string;
  stripeCustomerId: string | null;
  stripePaymentMethodId: string | null;
}

export interface TaskRecord {
  id: string;
  userId: string;
  title: string;
  dueDate: string;
  completedAt: string | null;
  status: string;
  rewardAmount: number;
  penaltyAmount: number;
}

export interface TransactionRecord {
  type: "reward" | "penalty";
  amount: number;
  status: "pending" | "succeeded" | "failed";
}

export interface PaymentStore {
  getProfile(userId: string): Promise<ProfileRecord | null>;
  setStripeCustomer(userId: string, customerId: string): Promise<void>;
  setPaymentMethod(userId: string, paymentMethodId: string): Promise<void>;
  completeTask(userId: string, taskId: string): Promise<TaskRecord | null>;
  getTaskTransaction(taskId: string, type: "reward" | "penalty"): Promise<TransactionRecord | null>;
  applyReward(userId: string, task: TaskRecord): Promise<void>;
  recordPenalty(
    userId: string,
    task: TaskRecord,
    paymentIntentId: string,
    status: "pending" | "succeeded" | "failed",
  ): Promise<void>;
}

export interface StripeGateway {
  createCustomer(
    userId: string,
    email: string,
    displayName: string,
  ): Promise<string>;
  createSetupIntent(customerId: string): Promise<{ clientSecret: string }>;
  attachPaymentMethod(customerId: string, paymentMethodId: string): Promise<void>;
  chargePenalty(input: {
    customerId: string;
    paymentMethodId: string;
    amountInCents: number;
    taskId: string;
    userId: string;
    description: string;
  }): Promise<{ id: string; status: string }>;
}

export class PaymentService {
  constructor(
    private readonly store: PaymentStore,
    private readonly stripe: StripeGateway,
  ) {}

  async createSetupIntent(userId: string): Promise<{ clientSecret: string }> {
    const profile = await this.requireProfile(userId);
    let customerId = profile.stripeCustomerId;
    if (customerId == null) {
      customerId = await this.stripe.createCustomer(
        userId,
        profile.email,
        profile.displayName,
      );
      await this.store.setStripeCustomer(userId, customerId);
    }
    return await this.stripe.createSetupIntent(customerId);
  }

  async savePaymentMethod(
    userId: string,
    paymentMethodId: unknown,
  ): Promise<{ success: true }> {
    if (typeof paymentMethodId !== "string" || !paymentMethodId.startsWith("pm_")) {
      throw new ApiError(400, "A valid paymentMethodId is required");
    }
    const profile = await this.requireProfile(userId);
    if (profile.stripeCustomerId == null) {
      throw new ApiError(409, "Create a SetupIntent before saving a payment method");
    }
    await this.stripe.attachPaymentMethod(profile.stripeCustomerId, paymentMethodId);
    await this.store.setPaymentMethod(userId, paymentMethodId);
    return { success: true };
  }

  async processTaskCompletion(
    userId: string,
    taskId: unknown,
  ): Promise<Record<string, string | number | boolean>> {
    if (typeof taskId !== "string" || taskId.length === 0) {
      throw new ApiError(400, "taskId is required");
    }
    const task = await this.store.completeTask(userId, taskId);
    if (task == null) throw new ApiError(404, "Task not found");
    if (task.completedAt == null) throw new ApiError(409, "Task could not be completed");
    const isOnTime = Date.parse(task.completedAt) <= Date.parse(task.dueDate);
    if (isOnTime && task.rewardAmount > 0) {
      const existing = await this.store.getTaskTransaction(task.id, "reward");
      if (existing == null) await this.store.applyReward(userId, task);
      return {
        message: `Reward of $${task.rewardAmount.toFixed(2)} credited!`,
        credited: task.rewardAmount,
        isOnTime,
      };
    }

    if (!isOnTime && task.penaltyAmount > 0) {
      const existing = await this.store.getTaskTransaction(task.id, "penalty");
      if (existing != null) {
        return {
          message: `Penalty of $${existing.amount.toFixed(2)} ${existing.status}.`,
          charged: existing.amount,
          isOnTime,
        };
      }
      const profile = await this.requireProfile(userId);
      if (profile.stripeCustomerId == null || profile.stripePaymentMethodId == null) {
        return { message: "Task completed late; no payment method was charged.", isOnTime };
      }
      const intent = await this.stripe.chargePenalty({
        customerId: profile.stripeCustomerId,
        paymentMethodId: profile.stripePaymentMethodId,
        amountInCents: Math.round(task.penaltyAmount * 100),
        taskId: task.id,
        userId,
        description: `You-Do penalty: ${task.title}`,
      });
      const status = intent.status === "succeeded" ? "succeeded" : "pending";
      await this.store.recordPenalty(userId, task, intent.id, status);
      return {
        message: `Penalty of $${task.penaltyAmount.toFixed(2)} ${status}.`,
        charged: task.penaltyAmount,
        isOnTime,
      };
    }

    return {
      message: isOnTime ? "Task completed on time!" : "Task completed late.",
      isOnTime,
    };
  }

  private async requireProfile(userId: string): Promise<ProfileRecord> {
    const profile = await this.store.getProfile(userId);
    if (profile == null) throw new ApiError(404, "Profile not found");
    return profile;
  }
}
