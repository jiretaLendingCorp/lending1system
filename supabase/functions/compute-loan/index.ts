// supabase/functions/compute-loan/index.ts
// Jireta Loans & Credit Corp. 1996
// Edge Function: Loan Computation Engine

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface LoanComputeRequest {
  principal_amount: number;
  payment_frequency: "daily" | "weekly" | "monthly";
  interest_rate?: number; // override; falls back to DB config
}

interface ScheduleEntry {
  schedule_number: number;
  due_amount: number;
  balance: number;
  due_offset_days: number; // days from disbursement
}

interface LoanComputeResponse {
  principal_amount: number;
  interest_rate: number;
  total_interest: number;
  total_payable: number;
  processing_fee: number;
  service_fee: number;
  ci_fee: number;
  total_charges: number;
  net_disbursement: number;
  term_days: number;
  payment_frequency: string;
  payment_amount: number;
  total_installments: number;
  schedule: ScheduleEntry[];
}

// Loan term mapping based on principal amount brackets
function getTermDays(amount: number, frequency: string): number {
  if (amount <= 10000) {
    return frequency === "daily" ? 40 : frequency === "weekly" ? 8 * 7 : 30;
  } else if (amount <= 30000) {
    return frequency === "daily" ? 60 : frequency === "weekly" ? 10 * 7 : 60;
  } else if (amount <= 75000) {
    return frequency === "daily" ? 80 : frequency === "weekly" ? 12 * 7 : 90;
  } else {
    return frequency === "daily" ? 120 : frequency === "weekly" ? 16 * 7 : 120;
  }
}

function getInstallmentCount(termDays: number, frequency: string): number {
  switch (frequency) {
    case "daily":   return termDays;
    case "weekly":  return Math.ceil(termDays / 7);
    case "monthly": return Math.ceil(termDays / 30);
    default:        return termDays;
  }
}

function getDueOffsetDays(installmentIndex: number, frequency: string): number {
  switch (frequency) {
    case "daily":   return installmentIndex;
    case "weekly":  return installmentIndex * 7;
    case "monthly": return installmentIndex * 30;
    default:        return installmentIndex;
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { persistSession: false } }
    );

    // Authenticate request
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: LoanComputeRequest = await req.json();

    // Input validation
    const { principal_amount, payment_frequency, interest_rate: overrideRate } = body;

    if (!principal_amount || typeof principal_amount !== "number") {
      throw new Error("principal_amount is required and must be a number");
    }
    if (!["daily", "weekly", "monthly"].includes(payment_frequency)) {
      throw new Error("payment_frequency must be daily, weekly, or monthly");
    }

    // Fetch loan settings from DB
    const { data: settings, error: settingsError } = await supabase
      .from("loan_settings")
      .select("setting_key, setting_value")
      .in("setting_key", [
        "default_interest_rate",
        "min_loan_amount",
        "max_loan_amount",
        "processing_fee_rate",
        "service_fee_rate",
        "ci_fee_flat",
      ]);

    if (settingsError) throw settingsError;

    const cfg = Object.fromEntries(
      (settings ?? []).map((s: { setting_key: string; setting_value: string }) => [
        s.setting_key,
        parseFloat(s.setting_value),
      ])
    );

    const minAmount        = cfg.min_loan_amount ?? 5000;
    const maxAmount        = cfg.max_loan_amount ?? 500000;
    const defaultRate      = cfg.default_interest_rate ?? 20;
    const processingFeeRate= cfg.processing_fee_rate ?? 2;
    const serviceFeeRate   = cfg.service_fee_rate ?? 1;
    const ciFeeFlat        = cfg.ci_fee_flat ?? 500;

    // Validate amount bounds
    if (principal_amount < minAmount) {
      throw new Error(`Minimum loan amount is ₱${minAmount.toLocaleString()}`);
    }
    if (principal_amount > maxAmount) {
      throw new Error(`Maximum loan amount is ₱${maxAmount.toLocaleString()}`);
    }

    // Compute interest
    const interestRate  = overrideRate ?? defaultRate;
    const totalInterest = parseFloat(((principal_amount * interestRate) / 100).toFixed(2));
    const totalPayable  = parseFloat((principal_amount + totalInterest).toFixed(2));

    // Compute fees
    const processingFee = parseFloat(((principal_amount * processingFeeRate) / 100).toFixed(2));
    const serviceFee    = parseFloat(((principal_amount * serviceFeeRate) / 100).toFixed(2));
    const ciFee         = ciFeeFlat;
    const totalCharges  = parseFloat((processingFee + serviceFee + ciFee).toFixed(2));
    const netDisbursement = parseFloat((principal_amount - totalCharges).toFixed(2));

    // Compute schedule
    const termDays         = getTermDays(principal_amount, payment_frequency);
    const totalInstallments= getInstallmentCount(termDays, payment_frequency);
    const basePayment      = parseFloat((totalPayable / totalInstallments).toFixed(2));

    // Adjust last installment for rounding differences
    const sumExceptLast   = parseFloat((basePayment * (totalInstallments - 1)).toFixed(2));
    const lastInstallment = parseFloat((totalPayable - sumExceptLast).toFixed(2));

    const schedule: ScheduleEntry[] = [];
    let runningBalance = totalPayable;

    for (let i = 1; i <= totalInstallments; i++) {
      const dueAmount = i === totalInstallments ? lastInstallment : basePayment;
      runningBalance  = parseFloat((runningBalance - dueAmount).toFixed(2));
      schedule.push({
        schedule_number: i,
        due_amount: dueAmount,
        balance: Math.max(0, runningBalance),
        due_offset_days: getDueOffsetDays(i, payment_frequency),
      });
    }

    const result: LoanComputeResponse = {
      principal_amount,
      interest_rate: interestRate,
      total_interest: totalInterest,
      total_payable: totalPayable,
      processing_fee: processingFee,
      service_fee: serviceFee,
      ci_fee: ciFee,
      total_charges: totalCharges,
      net_disbursement: netDisbursement,
      term_days: termDays,
      payment_frequency,
      payment_amount: basePayment,
      total_installments: totalInstallments,
      schedule,
    };

    return new Response(JSON.stringify({ data: result }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Internal server error";
    return new Response(JSON.stringify({ error: message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});