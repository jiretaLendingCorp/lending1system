// supabase/functions/process-payment/index.ts
// Jireta Loans & Credit Corp. 1996
// Edge Function: PayMongo Payment Processing
// NEVER expose secret keys to client — all PayMongo calls go through here

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PAYMONGO_BASE = "https://api.paymongo.com/v1";

type PaymentMethod = "gcash" | "maya" | "qrph" | "card";

interface CreatePaymentRequest {
  loan_id: string;
  schedule_id?: string;
  amount: number; // in PHP
  payment_method: PaymentMethod;
  return_url: string;
  description?: string;
}

function getPayMongoHeaders(): HeadersInit {
  const secretKey = Deno.env.get("PAYMONGO_SECRET_KEY");
  if (!secretKey) throw new Error("PayMongo secret key not configured");
  const encoded = btoa(`${secretKey}:`);
  return {
    Authorization: `Basic ${encoded}`,
    "Content-Type": "application/json",
  };
}

async function createPaymentLink(
  amount: number,
  description: string,
  returnUrl: string
): Promise<{ checkout_url: string; payment_link_id: string }> {
  const amountCents = Math.round(amount * 100);
  const res = await fetch(`${PAYMONGO_BASE}/links`, {
    method: "POST",
    headers: getPayMongoHeaders(),
    body: JSON.stringify({
      data: {
        attributes: {
          amount: amountCents,
          description,
          remarks: "Jireta Loans & Credit Corp. 1996",
        },
      },
    }),
  });
  const json = await res.json();
  if (!res.ok) {
    const msg = json?.errors?.[0]?.detail ?? "PayMongo link creation failed";
    throw new Error(msg);
  }
  return {
    checkout_url: json.data.attributes.checkout_url,
    payment_link_id: json.data.id,
  };
}

async function createGCashSource(
  amount: number,
  returnUrl: string,
  description: string
): Promise<{ checkout_url: string; source_id: string }> {
  const amountCents = Math.round(amount * 100);
  const res = await fetch(`${PAYMONGO_BASE}/sources`, {
    method: "POST",
    headers: getPayMongoHeaders(),
    body: JSON.stringify({
      data: {
        attributes: {
          amount: amountCents,
          currency: "PHP",
          type: "gcash",
          redirect: {
            success: returnUrl,
            failed: returnUrl + "?status=failed",
          },
          billing: { name: "Jireta Loans Customer" },
        },
      },
    }),
  });
  const json = await res.json();
  if (!res.ok) {
    const msg = json?.errors?.[0]?.detail ?? "GCash source creation failed";
    throw new Error(msg);
  }
  return {
    checkout_url: json.data.attributes.redirect.checkout_url,
    source_id: json.data.id,
  };
}

async function createMayaSource(
  amount: number,
  returnUrl: string
): Promise<{ checkout_url: string; source_id: string }> {
  const amountCents = Math.round(amount * 100);
  const res = await fetch(`${PAYMONGO_BASE}/sources`, {
    method: "POST",
    headers: getPayMongoHeaders(),
    body: JSON.stringify({
      data: {
        attributes: {
          amount: amountCents,
          currency: "PHP",
          type: "paymaya",
          redirect: {
            success: returnUrl,
            failed: returnUrl + "?status=failed",
          },
        },
      },
    }),
  });
  const json = await res.json();
  if (!res.ok) {
    const msg = json?.errors?.[0]?.detail ?? "Maya source creation failed";
    throw new Error(msg);
  }
  return {
    checkout_url: json.data.attributes.redirect.checkout_url,
    source_id: json.data.id,
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { persistSession: false } }
  );

  try {
    // Authenticate
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: { user }, error: authErr } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", "")
    );
    if (authErr || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: CreatePaymentRequest = await req.json();
    const { loan_id, schedule_id, amount, payment_method, return_url, description } = body;

    // Validate
    if (!loan_id || !amount || !payment_method || !return_url) {
      throw new Error("loan_id, amount, payment_method, and return_url are required");
    }
    if (amount <= 0) throw new Error("Amount must be greater than 0");
    if (!["gcash", "maya", "qrph", "card"].includes(payment_method)) {
      throw new Error("Invalid payment method");
    }

    // Fetch loan to verify lender ownership
    const { data: loan, error: loanErr } = await supabase
      .from("loans")
      .select("id, loan_code, lender_id, outstanding_balance, loan_status")
      .eq("id", loan_id)
      .single();

    if (loanErr || !loan) throw new Error("Loan not found");
    if (!["active", "overdue"].includes(loan.loan_status)) {
      throw new Error("Loan is not active or overdue");
    }
    if (amount > loan.outstanding_balance) {
      throw new Error("Amount exceeds outstanding balance");
    }

    // Generate payment code
    const paymentCode = `PAY-${Date.now()}-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
    const desc = description ?? `Payment for Loan ${loan.loan_code} - Jireta Loans`;

    let checkoutUrl = "";
    let sourceId: string | null = null;
    let paymongoId = "";

    // Create PayMongo resource based on method
    switch (payment_method) {
      case "gcash": {
        const result = await createGCashSource(amount, return_url, desc);
        checkoutUrl = result.checkout_url;
        sourceId    = result.source_id;
        paymongoId  = result.source_id;
        break;
      }
      case "maya": {
        const result = await createMayaSource(amount, return_url);
        checkoutUrl = result.checkout_url;
        sourceId    = result.source_id;
        paymongoId  = result.source_id;
        break;
      }
      case "qrph":
      case "card": {
        const result = await createPaymentLink(amount, desc, return_url);
        checkoutUrl = result.checkout_url;
        paymongoId  = result.payment_link_id;
        break;
      }
    }

    // Insert pending payment record
    const { data: payment, error: payErr } = await supabase
      .from("payments")
      .insert({
        payment_code:       paymentCode,
        loan_id,
        schedule_id:        schedule_id ?? null,
        lender_id:          loan.lender_id,
        amount,
        payment_method,
        payment_status:     "processing",
        paymongo_payment_id:paymongoId,
        paymongo_source_id: sourceId,
        remarks:            desc,
      })
      .select()
      .single();

    if (payErr) throw payErr;

    // Insert paymongo_transaction record
    await supabase.from("paymongo_transactions").insert({
      payment_id:          payment.id,
      paymongo_id:         paymongoId,
      transaction_type:    "payment",
      amount_cents:        Math.round(amount * 100),
      currency:            "PHP",
      status:              "pending",
      payment_method_type: payment_method,
      source_type:         sourceId ? "source" : "link",
      checkout_url:        checkoutUrl,
      return_url,
    });

    // Log audit
    await supabase.from("audit_logs").insert({
      user_id:     user.id,
      action:      "payment",
      table_name:  "payments",
      record_id:   payment.id,
      description: `Payment initiated: ${paymentCode} via ${payment_method}`,
    });

    return new Response(
      JSON.stringify({
        data: {
          payment_id:    payment.id,
          payment_code:  paymentCode,
          checkout_url:  checkoutUrl,
          amount,
          payment_method,
          status:        "processing",
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : "Payment processing error";
    return new Response(JSON.stringify({ error: message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});