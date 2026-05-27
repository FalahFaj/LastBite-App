import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { JWT } from "https://esm.sh/google-auth-library@8.7.0"

// Rumus Haversine untuk menghitung jarak antara dua koordinat (dalam km)
function getDistance(lat1: number, lon1: number, lat2: number, lon2: number) {
  const R = 6371; // Jari-jari bumi dalam km
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; 
}

serve(async (req) => {
  try {
    const { record, type } = await req.json()
    
    if (type !== 'INSERT') {
      return new Response(JSON.stringify({ message: "Not an INSERT event" }), { headers: { "Content-Type": "application/json" } })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Load Firebase Service Account dari Environment Variable
    const serviceAccount = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT') ?? '{}')
    
    async function sendNotification(tokens: string[], title: string, body: string) {
      if (tokens.length === 0) return;
      const client = new JWT({
        email: serviceAccount.client_email,
        key: serviceAccount.private_key,
        scopes: ['https://www.googleapis.com/auth/cloud-platform'],
      })
      const authTokens = await client.authorize()
      
      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`
      
      const promises = tokens.map(token => 
        fetch(fcmUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${authTokens.access_token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: token,
              notification: { title, body },
            },
          }),
        })
      );
      
      await Promise.all(promises);
    }

    const product = record;

    // 1. Dapatkan lokasi merchant
    const { data: merchant, error: merchantError } = await supabase
      .from('merchants')
      .select('store_name, latitude, longitude')
      .eq('id', product.merchant_id)
      .single()

    if (merchantError || !merchant || !merchant.latitude || !merchant.longitude) {
      return new Response(JSON.stringify({ error: "Lokasi merchant tidak ditemukan" }), { status: 400 });
    }

    // 2. Dapatkan semua user yang menyalakan notif dan memiliki token FCM dan koordinat
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('fcm_token, latitude, longitude')
      .eq('notify_nearby_discounts', true)
      .not('fcm_token', 'is', null)
      .not('latitude', 'is', null)
      .not('longitude', 'is', null)

    if (usersError || !users) {
      throw new Error("Gagal mengambil data user");
    }

    // 3. Filter berdasarkan jarak (<= 5km)
    const MAX_DISTANCE_KM = 5;
    const targetTokens: string[] = [];

    for (const user of users) {
      if (user.latitude && user.longitude && user.fcm_token) {
        const distance = getDistance(merchant.latitude, merchant.longitude, user.latitude, user.longitude);
        if (distance <= MAX_DISTANCE_KM) {
          targetTokens.push(user.fcm_token);
        }
      }
    }

    // 4. Kirim notifikasi massal ke token yang cocok
    if (targetTokens.length > 0) {
      const title = `Makanan Murah di Dekatmu! 🍽️`;
      const body = `${merchant.store_name} baru saja menambahkan ${product.name}. Yuk selamatkan sebelum kehabisan!`;
      await sendNotification(targetTokens, title, body);
    }

    return new Response(JSON.stringify({ success: true, notifiedCount: targetTokens.length }), { 
      headers: { "Content-Type": "application/json" } 
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { 
      status: 500,
      headers: { "Content-Type": "application/json" }
    })
  }
})
