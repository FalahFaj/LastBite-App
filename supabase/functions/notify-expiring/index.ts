import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { JWT } from "https://esm.sh/google-auth-library@8.7.0"

// Rumus Haversine untuk menghitung jarak antara dua koordinat (dalam km)
function getDistance(lat1: number, lon1: number, lat2: number, lon2: number) {
  const R = 6371;
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; 
}

serve(async () => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

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
            message: { token: token, notification: { title, body } },
          }),
        })
      );
      await Promise.all(promises);
    }

    // Waktu sekarang di WIB (UTC+7)
    const nowUtc = new Date();
    const currentHourWIB = (nowUtc.getUTCHours() + 7) % 24;
    const currentMinuteWIB = nowUtc.getUTCMinutes();
    const currentTimeInMinutes = currentHourWIB * 60 + currentMinuteWIB;
    
    // 1. Ambil produk yang masih tersedia
    const { data: products, error: productsError } = await supabase
      .from('products')
      .select('id, name, pickup_end, merchants(store_name, latitude, longitude)')
      .eq('status', 'available')

    if (productsError) throw productsError;

    // 2. Dapatkan semua user yang berlangganan pengingat dan memiliki koordinat
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('fcm_token, latitude, longitude')
      .eq('notify_expiring_offers', true)
      .not('fcm_token', 'is', null)
      .not('latitude', 'is', null)
      .not('longitude', 'is', null)

    if (usersError) throw usersError;

    let totalNotified = 0;
    const MAX_DISTANCE_KM = 5; // Radius 5km sesuai permintaan

    for (const product of products) {
      if (!product.pickup_end) continue;
      
      // Asumsi format pickup_end adalah "HH:MM:SS" dalam waktu WIB
      const parts = product.pickup_end.split(':');
      if (parts.length < 2) continue;
      
      const endHour = parseInt(parts[0], 10);
      const endMinute = parseInt(parts[1], 10);
      
      const productTimeInMinutes = endHour * 60 + endMinute;
      
      // Menghitung selisih waktu dalam menit
      let timeDiff = productTimeInMinutes - currentTimeInMinutes;
      
      // Penanganan perpindahan hari (contoh: sekarang 23:30, pickup 00:15)
      if (timeDiff < -12 * 60) {
        timeDiff += 24 * 60; 
      }
      
      // Jika kedaluwarsa dalam 1 hingga 60 menit dari sekarang
      if (timeDiff > 0 && timeDiff <= 60) {
        
        const targetTokens: string[] = [];
        const mLat = product.merchants?.latitude;
        const mLon = product.merchants?.longitude;
        
        if (!mLat || !mLon) continue;

        for (const user of users) {
          if (user.latitude && user.longitude && user.fcm_token) {
            const distance = getDistance(mLat, mLon, user.latitude, user.longitude);
            if (distance <= MAX_DISTANCE_KM) {
              targetTokens.push(user.fcm_token);
            }
          }
        }

        if (targetTokens.length > 0) {
          const title = `⏰ Segera Berakhir!`;
          const body = `${product.name} di ${product.merchants.store_name} sisa waktunya kurang dari 1 jam. Amankan sekarang!`;
          await sendNotification(targetTokens, title, body);
          totalNotified += targetTokens.length;
        }
      }
    }

    return new Response(JSON.stringify({ success: true, notified: totalNotified }), { 
      headers: { "Content-Type": "application/json" } 
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { 
      status: 500,
      headers: { "Content-Type": "application/json" }
    })
  }
})
