import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"
import { GoogleAuth } from "https://esm.sh/google-auth-library@8.7.0"

serve(async (req) => {
  try {
    const payload = await req.json()
    console.log("Webhook Payload:", payload)

    const record = payload.record
    if (!record) throw new Error("No record found in payload")

    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    if (!supabaseUrl || !supabaseServiceKey) throw new Error("Supabase credentials not set")
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    let muridId = record.id_murid
    let namaUser = record.nama_user || "Siswa"

    if (!muridId) {
      if (record.rfid) {
         const { data: muridData } = await supabase.from("murid").select("id_tabel").eq("rfid", record.rfid).single()
         if (muridData) muridId = muridData.id_tabel
      } else {
         const { data: muridData } = await supabase.from("murid").select("id_tabel").eq("nama", namaUser).single()
         if (muridData) muridId = muridData.id_tabel
      }
    }

    let targetUserId = muridId;

    if (!targetUserId && namaUser && namaUser !== "Siswa") {
      const { data: guruData } = await supabase.from("guru").select("id_tabel").eq("name", namaUser).maybeSingle()
      if (guruData) targetUserId = guruData.id_tabel
    }

    if (!targetUserId) {
      return new Response(JSON.stringify({ message: "No target user to notify" }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      })
    }

    const query = supabase.from("fcm_tokens").select("token").eq("user_id", targetUserId)

    const { data: tokensData, error: tokenError } = await query
    if (tokenError) throw tokenError

    const tokens = tokensData.map(t => t.token)
    if (tokens.length === 0) {
      return new Response(JSON.stringify({ message: "No devices to notify" }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      })
    }

    console.log(`Found ${tokens.length} tokens to notify.`)

    const fcmServiceAccountStr = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")
    if (!fcmServiceAccountStr) throw new Error("FIREBASE_SERVICE_ACCOUNT secret is missing")
    
    const serviceAccount = JSON.parse(fcmServiceAccountStr)

    const auth = new GoogleAuth({
      credentials: {
        client_email: serviceAccount.client_email,
        private_key: serviceAccount.private_key,
      },
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    })

    const accessToken = await auth.getAccessToken()

    const message = {
      message: {
        notification: {
          title: "Aplikasi Absensi",
          body: `${namaUser} telah melakukan absensi.`
        },
        data: {
          id_murid: muridId || "",
          nama_user: namaUser,
          id_tabel: record.id_tabel || "",
          type: "absen"
        }
      }
    }

    const projectId = serviceAccount.project_id
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

    const promises = tokens.map(async (token) => {
      const msg = { ...message, message: { ...message.message, token: token } }
      const res = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(msg),
      })
      if (!res.ok) {
        console.error(`Failed to send to ${token}:`, await res.text())
      }
    })

    await Promise.all(promises)

    return new Response(JSON.stringify({ success: true, notified: tokens.length }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (error) {
    console.error("Error:", error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
