// @ts-nocheck
// supabase/functions/scheduled-reminders/index.ts
// Jireta Loans & Credit Corp. 1996
// Edge Function: Scheduled Due Reminders + Auto Penalty Application
// Deploy as cron: every 1 hour  →  "0 * * * *"

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL            = Deno.env.get("SUPABASE_URL")             ?? "";
const SUPABASE_SERVICE_ROLE   = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SEND_NOTIF_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/send-notification`;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE, {
  auth: { persistSession: false },
});

// Helper: call send-notification edge function internally
async function sendNotification(payload: {
  recipient_id: string;
  notification_type: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}) {
  await fetch(SEND_NOTIF_FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type":  "application/json",
      "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE}`,
    },
    body: JSON.stringify(payload),
  });
}

// Step 1: Send payment due reminders (2 days before due)
async function processPaymentReminders(reminderDaysBefore: number) {
  const now   = new Date();
  const lower = new Date(now);
  lower.setDate(lower.getDate() + reminderDaysBefore);
  lower.setHours(0, 0, 0, 0);

  const upper = new Date(lower);
  upper.setHours(23, 59, 59, 999);

  const { data: schedules, error } = await supabase
    .from("loan_schedules")
    .select(`
      id, loan_id, schedule_number, due_amount, due_date,
      loans:loan_id (
        loan_code, lender_id,
        lenders:lender_id (
          user_id,
          users:user_id ( id, first_name, last_name, fcm_token )
        )
      )
    `)
    .eq("is_paid", false)
    .eq("reminder_sent", false)
    .gte("due_date", lower.toISOString())
    .lte("due_date", upper.toISOString());

  if (error) {
    console.error("Reminder fetch error:", error);
    return;
  }

  for (const schedule of schedules ?? []) {
    const loan: any    = schedule.loans;
    const lender: any  = loan?.lenders;
    const user: any    = lender?.users;

    if (!user?.id) continue;

    const dueDate = new Date(schedule.due_date).toLocaleDateString("en-PH", {
      month: "long", day: "numeric", year: "numeric",
    });

    await sendNotification({
      recipient_id:      user.id,
      notification_type: "payment_due",
      title:             "📅 Payment Due Soon",
      body:              `Your payment of ₱${schedule.due_amount.toLocaleString()} for Loan ${loan.loan_code} is due on ${dueDate}.`,
      data: {
        loan_id:       schedule.loan_id,
        schedule_id:   schedule.id,
        due_amount:    String(schedule.due_amount),
        due_date:      schedule.due_date,
      },
    });

    // Also notify assigned rider if any collection pending
    const { data: collection } = await supabase
      .from("collections")
      .select("rider_id, riders:rider_id(user_id, users:user_id(id))")
      .eq("schedule_id", schedule.id)
      .eq("collection_status", "assigned")
      .single();

    if (collection?.rider_id) {
      const riderUser: any = (collection as any).riders?.users;
      if (riderUser?.id) {
        await sendNotification({
          recipient_id:      riderUser.id,
          notification_type: "payment_due",
          title:             "🛵 Collection Reminder",
          body:              `Collection of ₱${schedule.due_amount.toLocaleString()} for Loan ${loan.loan_code} is due on ${dueDate}.`,
          data: {
            loan_id:     schedule.loan_id,
            schedule_id: schedule.id,
          },
        });
      }
    }

    // Mark reminder as sent
    await supabase
      .from("loan_schedules")
      .update({ reminder_sent: true, reminder_sent_at: new Date().toISOString() })
      .eq("id", schedule.id);
  }

  console.log(`Reminders processed: ${(schedules ?? []).length}`);
}

// Step 2: Mark overdue schedules
async function processOverdueSchedules(gracePeriodDays: number) {
  const graceCutoff = new Date();
  graceCutoff.setDate(graceCutoff.getDate() - gracePeriodDays);

  const { data: overdue, error } = await supabase
    .from("loan_schedules")
    .select("id, loan_id, due_amount, due_date")
    .eq("is_paid", false)
    .eq("is_overdue", false)
    .lt("due_date", graceCutoff.toISOString());

  if (error) {
    console.error("Overdue fetch error:", error);
    return;
  }

  for (const schedule of overdue ?? []) {
    await supabase
      .from("loan_schedules")
      .update({
        is_overdue:    true,
        overdue_since: schedule.due_date,
      })
      .eq("id", schedule.id);

    // Update loan status to overdue
    await supabase
      .from("loans")
      .update({ loan_status: "overdue", updated_at: new Date().toISOString() })
      .eq("id", schedule.loan_id)
      .eq("loan_status", "active");
  }

  console.log(`Overdue schedules: ${(overdue ?? []).length}`);
}

// Step 3: Apply daily penalty to overdue loans
async function applyPenalties(penaltyRateDaily: number) {
  const { data: overdueLoans, error } = await supabase
    .from("loans")
    .select(`
      id, loan_code, outstanding_balance, total_penalties,
      lender_id,
      lenders:lender_id(user_id, users:user_id(id, first_name))
    `)
    .eq("loan_status", "overdue")
    .eq("is_archived", false);

  if (error) {
    console.error("Penalty fetch error:", error);
    return;
  }

  for (const loan of overdueLoans ?? []) {
    const penaltyAmount = parseFloat(
      ((loan.outstanding_balance * penaltyRateDaily) / 100).toFixed(2)
    );
    if (penaltyAmount <= 0) continue;

    // Insert penalty record
    const { error: penErr } = await supabase.from("penalties").insert({
      loan_id:      loan.id,
      penalty_type: "late_fee",
      amount:       penaltyAmount,
      computed_days: 1,
      rate_applied:  penaltyRateDaily,
      description:   `Daily late penalty at ${penaltyRateDaily}% of outstanding balance`,
    });

    if (penErr) continue;

    // Update loan totals
    await supabase
      .from("loans")
      .update({
        total_penalties:   (loan.total_penalties ?? 0) + penaltyAmount,
        outstanding_balance: loan.outstanding_balance + penaltyAmount,
      })
      .eq("id", loan.id);

    // Notify lender
    const lenderUser: any = (loan as any).lenders?.users;
    if (lenderUser?.id) {
      await sendNotification({
        recipient_id:      lenderUser.id,
        notification_type: "penalty_applied",
        title:             "⚠️ Late Penalty Applied",
        body:              `A late penalty of ₱${penaltyAmount.toLocaleString()} has been added to Loan ${loan.loan_code}. Please settle your overdue balance.`,
        data: {
          loan_id:        loan.id,
          penalty_amount: String(penaltyAmount),
        },
      });
    }
  }

  console.log(`Penalties applied: ${(overdueLoans ?? []).length}`);
}

// Step 4: Auto-complete loans with zero balance
async function processCompletedLoans() {
  const { data: loans, error } = await supabase
    .from("loans")
    .select("id, loan_code, lender_id, lenders:lender_id(user_id, users:user_id(id))")
    .eq("loan_status", "active")
    .lte("outstanding_balance", 0);

  if (error) return;

  for (const loan of loans ?? []) {
    await supabase.from("loans").update({
      loan_status:  "completed",
      completed_at: new Date().toISOString(),
    }).eq("id", loan.id);

    const lenderUser: any = (loan as any).lenders?.users;
    if (lenderUser?.id) {
      await sendNotification({
        recipient_id:      lenderUser.id,
        notification_type: "loan_approved",
        title:             "🎉 Loan Fully Paid!",
        body:              `Congratulations! Loan ${loan.loan_code} has been fully settled. Thank you for your on-time payments!`,
        data: { loan_id: loan.id },
      });
    }
  }

  console.log(`Loans completed: ${(loans ?? []).length}`);
}

// Step 5: Invalidate expired lender sessions (10 min timeout)
async function expireSessions(timeoutMinutes: number) {
  const cutoff = new Date();
  cutoff.setMinutes(cutoff.getMinutes() - timeoutMinutes);

  const { error } = await supabase
    .from("sessions")
    .update({ is_active: false, invalidated_at: new Date().toISOString() })
    .eq("is_active", true)
    .lt("last_active_at", cutoff.toISOString());

  if (error) console.error("Session expiry error:", error);
  else console.log("Expired sessions cleaned up");
}

serve(async (_req: Request) => {
  console.log(`[${new Date().toISOString()}] Scheduled reminders running...`);

  // Fetch config values
  const { data: settings } = await supabase
    .from("loan_settings")
    .select("setting_key, setting_value")
    .in("setting_key", [
      "due_reminder_days_before",
      "grace_period_days",
      "penalty_rate_daily",
      "session_timeout_minutes",
    ]);

  const cfg = Object.fromEntries(
    (settings ?? []).map((s: { setting_key: string; setting_value: string }) => [
      s.setting_key,
      parseFloat(s.setting_value),
    ])
  );

  const reminderDaysBefore   = cfg.due_reminder_days_before   ?? 2;
  const gracePeriodDays      = cfg.grace_period_days          ?? 3;
  const penaltyRateDaily     = cfg.penalty_rate_daily         ?? 0.5;
  const sessionTimeoutMins   = cfg.session_timeout_minutes    ?? 10;

  await Promise.allSettled([
    processPaymentReminders(reminderDaysBefore),
    processOverdueSchedules(gracePeriodDays),
    applyPenalties(penaltyRateDaily),
    processCompletedLoans(),
    expireSessions(sessionTimeoutMins),
  ]);

  return new Response(
    JSON.stringify({ message: "Scheduled tasks completed", timestamp: new Date().toISOString() }),
    { headers: { "Content-Type": "application/json" }, status: 200 }
  );
});