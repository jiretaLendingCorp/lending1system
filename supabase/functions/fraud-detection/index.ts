// supabase/functions/fraud-detection/index.ts
// Jireta Loans & Credit Corp. 1996
// Edge Function: Fraud Detection & Risk Scoring

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  { auth: { persistSession: false } }
);

interface FraudCheckRequest {
  user_id: string;
  event_type: "login" | "loan_application" | "payment" | "document_upload";
  ip_address?: string;
  device_id?: string;
  metadata?: Record<string, unknown>;
}

interface RiskSignal {
  signal: string;
  severity: "low" | "medium" | "high" | "critical";
  score: number;
  details: string;
}

async function checkFailedLoginRate(userId: string, ipAddress?: string): Promise<RiskSignal[]> {
  const signals: RiskSignal[] = [];
  const cutoff = new Date();
  cutoff.setHours(cutoff.getHours() - 1);

  // Check login failures by IP in last hour
  if (ipAddress) {
    const { count } = await supabase
      .from("failed_login_attempts")
      .select("*", { count: "exact", head: true })
      .eq("ip_address", ipAddress)
      .gte("attempted_at", cutoff.toISOString());

    if ((count ?? 0) >= 10) {
      signals.push({
        signal:   "high_failed_login_rate_ip",
        severity: "high",
        score:    40,
        details:  `${count} failed logins from IP ${ipAddress} in 1 hour`,
      });
    } else if ((count ?? 0) >= 5) {
      signals.push({
        signal:   "moderate_failed_login_rate_ip",
        severity: "medium",
        score:    20,
        details:  `${count} failed logins from IP ${ipAddress} in 1 hour`,
      });
    }
  }

  return signals;
}

async function checkMultipleLoanApplications(userId: string): Promise<RiskSignal[]> {
  const signals: RiskSignal[] = [];
  const { data: lender } = await supabase
    .from("lenders")
    .select("id, active_loan_count, total_overdue_count, is_blacklisted")
    .eq("user_id", userId)
    .single();

  if (!lender) return signals;

  if (lender.is_blacklisted) {
    signals.push({
      signal:   "blacklisted_user_applying",
      severity: "critical",
      score:    100,
      details:  "Blacklisted user attempting loan application",
    });
  }

  if ((lender.active_loan_count ?? 0) >= 1) {
    signals.push({
      signal:   "existing_active_loan",
      severity: "high",
      score:    60,
      details:  "User already has an active loan",
    });
  }

  if ((lender.total_overdue_count ?? 0) >= 3) {
    signals.push({
      signal:   "repeated_overdue_history",
      severity: "high",
      score:    50,
      details:  `User has ${lender.total_overdue_count} overdue records`,
    });
  } else if ((lender.total_overdue_count ?? 0) >= 1) {
    signals.push({
      signal:   "past_overdue_history",
      severity: "medium",
      score:    25,
      details:  `User has ${lender.total_overdue_count} past overdue`,
    });
  }

  return signals;
}

async function checkUnusualPaymentPattern(
  userId: string,
  metadata?: Record<string, unknown>
): Promise<RiskSignal[]> {
  const signals: RiskSignal[] = [];
  const { data: lender } = await supabase
    .from("lenders")
    .select("id")
    .eq("user_id", userId)
    .single();

  if (!lender) return signals;

  // Check for rapid repeated payment attempts in 15 min
  const cutoff = new Date();
  cutoff.setMinutes(cutoff.getMinutes() - 15);

  const { count } = await supabase
    .from("payments")
    .select("*", { count: "exact", head: true })
    .eq("lender_id", lender.id)
    .eq("payment_status", "processing")
    .gte("created_at", cutoff.toISOString());

  if ((count ?? 0) >= 5) {
    signals.push({
      signal:   "rapid_payment_attempts",
      severity: "high",
      score:    45,
      details:  `${count} payment attempts in 15 minutes`,
    });
  }

  return signals;
}

async function checkSuspiciousDocumentUploads(userId: string): Promise<RiskSignal[]> {
  const signals: RiskSignal[] = [];
  const { data: lender } = await supabase
    .from("lenders")
    .select("id")
    .eq("user_id", userId)
    .single();

  if (!lender) return signals;

  // Check rapid document uploads (>10 in 1 hour)
  const cutoff = new Date();
  cutoff.setHours(cutoff.getHours() - 1);
  const { count } = await supabase
    .from("lender_documents")
    .select("*", { count: "exact", head: true })
    .eq("lender_id", lender.id)
    .gte("created_at", cutoff.toISOString());

  if ((count ?? 0) > 10) {
    signals.push({
      signal:   "excessive_document_uploads",
      severity: "medium",
      score:    30,
      details:  `${count} document uploads in 1 hour`,
    });
  }

  return signals;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: FraudCheckRequest = await req.json();
    const { user_id, event_type, ip_address, metadata } = body;

    if (!user_id || !event_type) {
      throw new Error("user_id and event_type are required");
    }

    let signals: RiskSignal[] = [];

    switch (event_type) {
      case "login":
        signals = [
          ...signals,
          ...(await checkFailedLoginRate(user_id, ip_address)),
        ];
        break;
      case "loan_application":
        signals = [
          ...signals,
          ...(await checkMultipleLoanApplications(user_id)),
        ];
        break;
      case "payment":
        signals = [
          ...signals,
          ...(await checkUnusualPaymentPattern(user_id, metadata)),
        ];
        break;
      case "document_upload":
        signals = [
          ...signals,
          ...(await checkSuspiciousDocumentUploads(user_id)),
        ];
        break;
    }

    // Compute total risk score
    const totalScore  = signals.reduce((sum, s) => sum + s.score, 0);
    const riskLevel   = totalScore >= 80 ? "critical"
                      : totalScore >= 50 ? "high"
                      : totalScore >= 25 ? "medium"
                      : "low";
    const shouldBlock = totalScore >= 100;
    const shouldFlag  = totalScore >= 50;

    // Store fraud flags if flagged
    if (shouldFlag && signals.length > 0) {
      for (const signal of signals) {
        if (signal.score >= 25) {
          await supabase.from("fraud_flags").insert({
            user_id,
            flag_type:   signal.signal,
            severity:    signal.severity,
            description: signal.details,
            metadata: {
              event_type,
              ip_address,
              risk_score: totalScore,
              signals: signals.map((s) => s.signal),
            },
          });
        }
      }

      // Notify head manager of critical fraud
      if (riskLevel === "critical") {
        const { data: admins } = await supabase
          .from("users")
          .select("id")
          .eq("account_status", "active")
          .in(
            "role_id",
            supabase.from("roles").select("id").eq("name", "head_manager")
          );

        for (const admin of admins ?? []) {
          await fetch(
            `${Deno.env.get("SUPABASE_URL")}/functions/v1/send-notification`,
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
              },
              body: JSON.stringify({
                recipient_id:      admin.id,
                notification_type: "system_alert",
                title:             "🚨 Fraud Alert Detected",
                body:              `Critical fraud signals detected for user. Risk score: ${totalScore}. Event: ${event_type}`,
                data: { user_id, event_type, risk_score: String(totalScore) },
              }),
            }
          );
        }
      }
    }

    return new Response(
      JSON.stringify({
        data: {
          risk_level:   riskLevel,
          risk_score:   totalScore,
          should_block: shouldBlock,
          should_flag:  shouldFlag,
          signals:      signals.map((s) => ({
            signal:   s.signal,
            severity: s.severity,
            details:  s.details,
          })),
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : "Fraud detection error";
    return new Response(JSON.stringify({ error: message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});