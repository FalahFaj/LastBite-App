import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { JWT } from "https://esm.sh/google-auth-library@8.7.0"

serve(async (req) => {
  try {
    const { record, old_record, type } = await req.json()
    
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
            data: dataPayload, // Menambahkan data rute
          },
        }),
      })
      
      return response.json()
    }

    // LOGIC: NEW ORDER (Merchant Notification)
    if (type === 'INSERT') {
      const { data: merchantData, error: mError } = await supabase
        .from('order_items')
        .select(`
          products (
            name,
            merchants (
              user_id,
              users (fcm_token)
            )
          )
        `)
        .eq('order_id', record.id)
        .limit(1)
        .single()

      if (mError) throw mError

      const token = merchantData?.products?.merchants?.users?.fcm_token
      const productName = merchantData?.products?.name || 'makanan'

      if (token) {
        await sendNotification(
          token, 
          "Ada Pesanan Baru! 🍔", 
          `Satu pesanan baru (${productName}) masuk. Ayo cek dan konfirmasi sekarang!`,
          { route: '/merchant/orders' } // Konteks untuk buka app ke halaman pesanan merchant
        )
      }
    }

    // LOGIC: STATUS READY (Buyer Notification)
    if (type === 'UPDATE' && record.status === 'ready_for_pickup' && old_record.status !== 'ready_for_pickup') {
      // 1. Ambil token pembeli
      const { data: userData, error: uError } = await supabase
        .from('users')
        .select('fcm_token')
        .eq('id', record.buyer_id)
        .single()

      if (uError) throw uError

      // 2. Ambil nama produk dari order_items
      const { data: itemData } = await supabase
        .from('order_items')
        .select('products(name)')
        .eq('order_id', record.id)
        .limit(1)
        .single()
        
      const productName = itemData?.products?.name || 'makanan'
      const deliveryMethod = record.delivery_method || 'pickup'
      
      if (userData?.fcm_token) {
        let title = ""
        let body = ""
        
        // Perkondisian metode pengiriman
        if (deliveryMethod === 'delivery') {
          title = "Pesanan Sedang Diantar! 🛵"
          body = `Pesananmu (${productName}) sedang dalam perjalanan ke tempatmu oleh penjual.`
        } else {
          title = "Pesanan Siap Diambil! ✅"
          body = `Pesananmu (${productName}) sudah siap. Silakan datang ambil di lokasi penjual ya!`
        }

        await sendNotification(
          userData.fcm_token, 
          title, 
          body,
          { route: '/user/orders' } // Konteks untuk buka app ke halaman pesanan pembeli
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
