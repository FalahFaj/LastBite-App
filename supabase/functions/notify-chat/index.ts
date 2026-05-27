import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { JWT } from "https://esm.sh/google-auth-library@8.7.0"

serve(async (req) => {
  try {
    const { record, type } = await req.json()
    
    // Initialize Supabase Client
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Load Firebase Service Account
    const serviceAccount = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT') ?? '{}')
    
    async function sendNotification(token: string, title: string, body: string, dataPayload: Record<string, string> = {}) {
      const client = new JWT({
        email: serviceAccount.client_email,
        key: serviceAccount.private_key,
        scopes: ['https://www.googleapis.com/auth/cloud-platform'],
      })
      const tokens = await client.authorize()
      
      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`
      
      const response = await fetch(fcmUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${tokens.access_token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: token,
            notification: { title, body },
            data: dataPayload,
          },
        }),
      })
      
      return response.json()
    }

    if (type === 'INSERT') {
      const { chat_id, sender_id, content } = record;

      // Ambil detail chat untuk mendapatkan buyer_id dan merchant_id (serta user_id merchant)
      const { data: chatData, error: chatError } = await supabase
        .from('chats')
        .select(`
          buyer_id,
          merchant_id,
          merchants ( user_id )
        `)
        .eq('id', chat_id)
        .single()

      if (chatError) throw chatError

      // Tentukan siapa penerimanya
      const isSenderBuyer = sender_id === chatData.buyer_id;
      const receiverUserId = isSenderBuyer ? chatData.merchants.user_id : chatData.buyer_id;

      // Ambil token fcm penerima
      const { data: receiverData, error: rError } = await supabase
        .from('users')
        .select('fcm_token')
        .eq('id', receiverUserId)
        .single()

      if (rError) throw rError

      // Ambil nama pengirim untuk ditampilkan di notif
      const { data: senderData, error: sError } = await supabase
        .from('users')
        .select('name')
        .eq('id', sender_id)
        .single()
        
      const senderName = senderData?.name || 'Seseorang';
      const receiverToken = receiverData?.fcm_token;
      const targetRoute = isSenderBuyer ? '/merchant/chats' : '/chat';

      if (receiverToken) {
        await sendNotification(
          receiverToken, 
          `Pesan Baru dari ${senderName} 💬`, 
          content || 'Mengirim sebuah pesan.',
          { route: targetRoute } // Rute agar kalau di-tap bisa masuk ke daftar chat
        )
      }
    }

    return new Response(JSON.stringify({ success: true }), { 
      headers: { "Content-Type": "application/json" } 
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { 
      status: 500,
      headers: { "Content-Type": "application/json" }
    })
  }
})
