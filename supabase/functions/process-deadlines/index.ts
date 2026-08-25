import { SupabaseClient } from "npm:@supabase/supabase-js@2.57.4";

import { DeadlineService, DeadlineStore } from "../_shared/deadline_service.ts";
import { ProfileRecord, TaskRecord } from "../_shared/payment_service.ts";
import {
  createAdminClient,
  createStripeClient,
  requiredEnv,
  StripeSdkGateway,
} from "../_shared/runtime.ts";

class SupabaseDeadlineStore implements DeadlineStore {
  constructor(private readonly admin: SupabaseClient) {}

  async claimOverdueTasks(limit: number): Promise<TaskRecord[]> {
    const { data, error } = await this.admin.rpc("claim_overdue_tasks", { p_limit: limit });
    if (error) throw error;
    return ((data ?? []) as Array<Record<string, unknown>>).map((row) => ({
      id: row.id as string,
      userId: row.user_id as string,
      title: row.title as string,
      dueDate: row.due_date as string,
      completedAt: row.completed_at as string | null,
      status: row.status as string,
      rewardAmount: Number(row.reward_amount),
      penaltyAmount: Number(row.penalty_amount),
    }));
  }

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

  async hasPenaltyTransaction(taskId: string): Promise<boolean> {
    const { count, error } = await this.admin.from("transactions")
      .select("id", { count: "exact", head: true }).eq("task_id", taskId).eq("type", "penalty");
    if (error) throw error;
    return (count ?? 0) > 0;
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

const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
const service = new DeadlineService(
  new SupabaseDeadlineStore(createAdminClient()),
  new StripeSdkGateway(createStripeClient()),
);

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (request.headers.get("apikey") !== serviceRoleKey) {
    return new Response("Authentication required", { status: 401 });
  }
  try {
    return Response.json(await service.process());
  } catch (error) {
    console.error(error);
    return Response.json({ error: "Deadline processing failed" }, { status: 500 });
  }
});
