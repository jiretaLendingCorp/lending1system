// supabase/functions/send-notification/index.ts
// Jireta Loans & Credit Corp. 1996
// Edge Function: FCM Push Notification Sender

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const FCM_URL = "https://fcm.googleapis.com/v1/projects";

interface NotificationPayload {
  recipient_id: string;
  notification_type: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  sender_id?: string;
}

async function getFCMAccessToken(): Promise<string> {
  const serviceAccount = JSON.parse(
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}"
  );
  // Google OAuth2 JWT flow for service accounts
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = btoa(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));

  // Sign with private key (using crypto)
  const keyData = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");

  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signingInput = `${header}.${payload}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );
  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)));
  const jwt = `${signingInput}.${signatureB64}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenJson = await tokenRes.json();
  return tokenJson.access_token;
}

async function sendFCMMessage(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
  accessToken: string,
  projectId: string
): Promise<{ success: boolean; messageId?: string; error?: string }> {
  const url = `${FCM_URL}/${projectId}/messages:send`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token: fcmToken,
        notification: { title, body },
        data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channel_id: "jireta_loans_default",
            icon: "ic_notification",
            color: "#0EA5E9",
          },
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        webpush: {
          headers: { Urgency: "high" },
          notification: { icon: "/icons/icon-192x192.png", badge: "/icons/badge-72x72.png" },
        },
      },
    }),
  });

  const json = await res.json();
  if (!res.ok) {
    return { success: false, error: json?.error?.message ?? "FCM send failed" };
  }
  return { success: true, messageId: json.name };
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

    const payload: NotificationPayload = await req.json();
    const { recipient_id, notification_type, title, body, data, sender_id } = payload;

    if (!recipient_id || !notification_type || !title || !body) {
      throw new Error("recipient_id, notification_type, title, and body are required");
    }

    // Get recipient FCM token
    const { data: user, error: userErr } = await supabase
      .from("users")
      .select("id, fcm_token, account_status")
      .eq("id", recipient_id)
      .single();

    if (userErr || !user) throw new Error("Recipient not found");
    if (user.account_status === "suspended") throw new Error("Recipient account is suspended");

    // Insert notification record
    const { data: notif, error: notifErr } = await supabase
      .from("notifications")
      .insert({
        recipient_id,
        sender_id: sender_id ?? null,
        notification_type,
        title,
        body,
        data: data ?? {},
        sent_via_push: !!user.fcm_token,
      })
      .select()
      .single();

    if (notifErr) throw notifErr;

    // Send FCM push if token available
    let pushResult = { success: false, error: "No FCM token" };

    if (user.fcm_token) {
      const projectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
      const accessToken = await getFCMAccessToken();
      pushResult = await sendFCMMessage(
        user.fcm_token,
        title,
        body,
        {
          notification_id:   notif.id,
          notification_type,
          ...(data ?? {}),
        },
        accessToken,
        projectId
      );

      // Update notification push status
      await supabase
        .from("notifications")
        .update({
          push_sent_at:  pushResult.success ? new Date().toISOString() : null,
          push_failed:   !pushResult.success,
          push_fail_reason: pushResult.error ?? null,
          fcm_message_id:   pushResult.messageId ?? null,
        })
        .eq("id", notif.id);
    }

    return new Response(
      JSON.stringify({
        data: {
          notification_id: notif.id,
          push_sent:       pushResult.success,
          push_error:      pushResult.error,
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : "Notification error";
    return new Response(JSON.stringify({ error: message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});