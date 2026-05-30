// @ts-nocheck
// supabase/functions/archive-record/index.ts
// Jireta Loans & Credit Corp. 1996
// Edge Function: Safe Archive / Restore operations with audit log

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type ArchivableTable =
  | "users" | "loans" | "payments" | "collections"
  | "ci_assignments" | "ci_reports" | "lender_documents"
  | "notifications" | "payment_receipts" | "riders"
  | "lenders" | "employees" | "loan_products";

const ARCHIVABLE_TABLES: ArchivableTable[] = [
  "users", "loans", "payments", "collections",
  "ci_assignments", "ci_reports", "lender_documents",
  "notifications", "payment_receipts", "riders",
  "lenders", "employees", "loan_products",
];

interface ArchiveRequest {
  table_name: ArchivableTable;
  record_id:  string;
  action:     "archive" | "restore";
  reason?:    string;
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
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify actor
    const { data: { user: actor }, error: actorErr } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", "")
    );
    if (actorErr || !actor) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get actor's DB user
    const { data: actorUser } = await supabase
      .from("users")
      .select("id, role_id, roles:role_id(name)")
      .eq("auth_id", actor.id)
      .single();

    if (!actorUser) throw new Error("Actor user not found");

    const roleName: string = (actorUser as any).roles?.name ?? "";
    if (!["head_manager", "employee"].includes(roleName)) {
      return new Response(JSON.stringify({ error: "Insufficient permissions" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: ArchiveRequest = await req.json();
    const { table_name, record_id, action, reason } = body;

    if (!table_name || !record_id || !action) {
      throw new Error("table_name, record_id, and action are required");
    }
    if (!ARCHIVABLE_TABLES.includes(table_name)) {
      throw new Error(`Table '${table_name}' is not archivable`);
    }
    if (!["archive", "restore"].includes(action)) {
      throw new Error("action must be 'archive' or 'restore'");
    }

    const now = new Date().toISOString();
    const updatePayload =
      action === "archive"
        ? { is_archived: true,  archived_at: now,  archived_by: actorUser.id }
        : { is_archived: false, archived_at: null, archived_by: null };

    const { data: updated, error: updateErr } = await supabase
      .from(table_name)
      .update(updatePayload)
      .eq("id", record_id)
      .select()
      .single();

    if (updateErr) throw updateErr;

    // Audit log
    await supabase.from("audit_logs").insert({
      user_id:     actorUser.id,
      action:      action === "archive" ? "archive" : "restore",
      table_name,
      record_id,
      new_values:  updatePayload,
      description: `${action === "archive" ? "Archived" : "Restored"} record from ${table_name}${reason ? `: ${reason}` : ""}`,
    });

    // If archiving a user, invalidate all their sessions
    if (action === "archive" && table_name === "users") {
      await supabase
        .from("sessions")
        .update({ is_active: false, invalidated_at: now })
        .eq("user_id", record_id)
        .eq("is_active", true);
    }

    return new Response(
      JSON.stringify({
        data: { record_id, table_name, action, success: true },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : "Archive error";
    return new Response(JSON.stringify({ error: message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});