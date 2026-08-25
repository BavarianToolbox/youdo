import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2.57.4";
import Stripe from "npm:stripe@16.12.0";

import { Authenticator } from "./http.ts";
import {
  PaymentService,
  PaymentStore,
  ProfileRecord,
  StripeGateway,
  TaskRecord,
  TransactionRecord,
} from "./payment_service.ts";

export function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (value == null || value.length === 0) throw new Error(`${name} is required`);
  return value;
}

export function createAdminClient(): SupabaseClient {
  return createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

export function createStripeClient(): Stripe {
  return new Stripe(requiredEnv("STRIPE_SECRET_KEY"), {
    apiVersion: "2024-06-20",
  });
}

class SupabaseAuthenticator implements Authenticator {
  constructor(private readonly admin: SupabaseClient) {}

  async getUserId(authorization: string): Promise<string | null> {
    const token = authorization.replace(/^Bearer\s+/i, "");
    if (token.length === 0) return null;
    const { data, error } = await this.admin.auth.getUser(token);
    return error == null ? data.user?.id ?? null : null;
  }
}

class SupabasePaymentStore implements PaymentStore {
  constructor(private readonly admin: SupabaseClient) {}

  async getProfile(userId: string): Promise<ProfileRecord | null> {
    const { data, error } = await this.admin.from("profiles").select(
      "id,email,display_name,stripe_customer_id,stripe_payment_method_id",
    ).eq("id", userId).maybeSingle();
    if (error) throw error;
    return data == null ? null : {
      id: data.id,
      email: data.email,
      displayName: data.display_name,
      stripeCustomerId: data.stripe_customer_id,
      stripePaymentMethodId: data.stripe_payment_method_id,
    };
  }

  async setStripeCustomer(userId: string, customerId: string): Promise<void> {
    const { error } = await this.admin.from("profiles")
      .update({ stripe_customer_id: customerId }).eq("id", userId);
    if (error) throw error;
  }

  async setPaymentMethod(userId: string, paymentMethodId: string): Promise<void> {
    const { error } = await this.admin.from("profiles").update({
      stripe_payment_method_id: paymentMethodId,
      has_payment_method: true,
    }).eq("id", userId);
    if (error) throw error;
  }

  async completeTask(userId: string, taskId: string): Promise<TaskRecord | null> {
    const { data, error } = await this.admin.rpc("complete_task", {
      p_user_id: userId,
      p_task_id: taskId,
    }).maybeSingle();
    if (error) throw error;
    if (data == null) return null;
    const row = data as {
      id: string;
      user_id: string;
      title: string;
      due_date: string;
      completed_at: string | null;
      status: string;
      reward_amount: number | string;
      penalty_amount: number | string;
    };
    return {
      id: row.id,
      userId: row.user_id,
      title: row.title,
      dueDate: row.due_date,
      completedAt: row.completed_at,
      status: row.status,
      rewardAmount: Number(row.reward_amount),
      penaltyAmount: Number(row.penalty_amount),
    };
  }

  async getTaskTransaction(
    taskId: string,
    type: "reward" | "penalty",
  ): Promise<TransactionRecord | null> {
    const { data, error } = await this.admin.from("transactions")
      .select("type,amount,status").eq("task_id", taskId).eq("type", type)
      .maybeSingle();
    if (error) throw error;
    return data == null ? null : {
      type: data.type,
      amount: Number(data.amount),
      status: data.status,
    };
  }

  async applyReward(userId: string, task: TaskRecord): Promise<void> {
    const { error } = await this.admin.rpc("apply_task_reward", {
      p_user_id: userId,
      p_task_id: task.id,
    });
    if (error) throw error;
  }

  async recordPenalty(
    userId: string,
    task: TaskRecord,
    paymentIntentId: string,
    status: "pending" | "succeeded" | "failed",
  ): Promise<void> {
    const { error } = await this.admin.rpc("record_task_penalty", {
      p_user_id: userId,
      p_task_id: task.id,
      p_stripe_intent_id: paymentIntentId,
      p_status: status,
    });
    if (error) throw error;
  }
}

export class StripeSdkGateway implements StripeGateway {
  constructor(private readonly stripe: Stripe) {}

  async createCustomer(userId: string, email: string, displayName: string): Promise<string> {
    const customer = await this.stripe.customers.create({
      email,
      name: displayName || undefined,
      metadata: { supabaseUserId: userId },
    }, { idempotencyKey: `profile:${userId}:customer` });
    return customer.id;
  }

  async createSetupIntent(customerId: string): Promise<{ clientSecret: string }> {
    const intent = await this.stripe.setupIntents.create({
      customer: customerId,
      payment_method_types: ["card"],
      usage: "off_session",
    });
    if (intent.client_secret == null) throw new Error("Stripe did not return a client secret");
    return { clientSecret: intent.client_secret };
  }

  async attachPaymentMethod(customerId: string, paymentMethodId: string): Promise<void> {
    await this.stripe.paymentMethods.attach(paymentMethodId, { customer: customerId });
    await this.stripe.customers.update(customerId, {
      invoice_settings: { default_payment_method: paymentMethodId },
    });
  }

  async chargePenalty(input: {
    customerId: string;
    paymentMethodId: string;
    amountInCents: number;
    taskId: string;
    userId: string;
    description: string;
  }): Promise<{ id: string; status: string }> {
    return await this.stripe.paymentIntents.create({
      amount: input.amountInCents,
      currency: "usd",
      customer: input.customerId,
      payment_method: input.paymentMethodId,
      confirm: true,
      off_session: true,
      description: input.description,
      metadata: { taskId: input.taskId, userId: input.userId },
    }, { idempotencyKey: `task:${input.taskId}:penalty` });
  }
}

export function createRuntime(): {
  authenticator: Authenticator;
  service: PaymentService;
} {
  const admin = createAdminClient();
  const stripe = createStripeClient();
  return {
    authenticator: new SupabaseAuthenticator(admin),
    service: new PaymentService(
      new SupabasePaymentStore(admin),
      new StripeSdkGateway(stripe),
    ),
  };
}
