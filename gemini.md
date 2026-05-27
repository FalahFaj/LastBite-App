📦 CONTEXT UNTUK AI AGENT (FLUTTER APP – LASTBITE)
🧠 Project Overview

Nama aplikasi: LastBite

Deskripsi:
LastBite adalah aplikasi mobile berbasis Flutter yang menghubungkan pedagang makanan (merchant) dengan pembeli untuk menjual makanan sisa dengan harga diskon. Pembeli dapat melihat daftar makanan terdekat, melakukan pemesanan, dan mengambil langsung ke lokasi penjual (COD).

Tujuan MVP:

Menyediakan platform sederhana untuk upload makanan sisa
Menampilkan daftar makanan ke pengguna
Memungkinkan pengguna melakukan order (tanpa pembayaran online)
Fokus pada kecepatan dan kemudahan penggunaan
👥 User Roles
1. User (Pembeli)
Melihat daftar makanan
Melihat detail makanan
Melakukan order
Melihat riwayat order
2. Merchant (Penjual)
Login/register
Menambahkan produk makanan sisa
Mengelola produk
Melihat order masuk
📱 Platform
Mobile app menggunakan Flutter
Target: Android (utama), iOS (opsional)
🧱 App Architecture

Gunakan arsitektur sederhana dan scalable:

State management: Provider / Riverpod (disarankan Riverpod)
Networking: Dio / HTTP
Routing: GoRouter / Navigator 2.0
Local storage: SharedPreferences / Hive
🧭 App Navigation Structure
Auth Flow
Splash Screen
Login Screen
Register Screen
User Flow (Pembeli)
Home Screen (list makanan)
Detail Screen
Order Screen / Confirmation
Order History Screen
Profile Screen
Merchant Flow
Dashboard Screen
Add Product Screen
Product List Screen
Order List Screen
Profile Screen
📦 Core Features (MVP)
Authentication
Register (name, email, password, role)
Login
Logout
Product (Makanan)
List semua makanan
Detail makanan
Tambah makanan (merchant)
Edit & delete makanan (merchant)

Field produk:

name
description
price
original_price
image
pickup_time
location
status (available/sold)
Order
User bisa order makanan
Status: pending / completed
Merchant bisa lihat order
🗄️ API Structure (Assumption)

Base URL:

https://api.lastbite.com
Auth
POST /register
POST /login
Products
GET /products
GET /products/{id}
POST /products
PUT /products/{id}
DELETE /products/{id}
Orders
POST /orders
GET /orders/user
GET /orders/merchant

🧪 MVP Scope (IMPORTANT)

Fokus hanya:

Auth
CRUD produk
Order sederhana
UI basic

JANGAN buat:

payment gateway
chat realtime
maps complex
push notification
⚡ Non-Functional Requirements
ringan dan cepat
mudah digunakan
error handling sederhana
responsive UI
📌 Development Notes
Gunakan dummy data jika API belum siap
Pisahkan folder:
models
services
providers
screens
widgets

Schema database

🧩 1. Tabel users
id (UUID, Primary Key) → Berelasi langsung dengan auth.users.id (Supabase Auth)
name (Text) → Nama lengkap pengguna
created_at (Timestamp) → Waktu akun dibuat
🏪 2. Tabel merchants
id (UUID, Primary Key) → ID unik merchant/toko
user_id (UUID, Foreign Key) → Relasi ke users.id (pemilik toko)
store_name (Text) → Nama toko/penjual
location (Text) → Alamat/deskripsi lokasi toko
latitude (Numeric) → Koordinat lintang lokasi toko
longitude (Numeric) → Koordinat bujur lokasi toko
created_at (Timestamp) → Waktu toko dibuat
🛒 3. Tabel products
id (UUID, Primary Key) → ID unik produk
merchant_id (UUID, Foreign Key) → Relasi ke merchants.id
name (Text) → Nama produk
description (Text) → Deskripsi produk
price (Numeric) → Harga jual (setelah diskon)
original_price (Numeric) → Harga asli sebelum diskon
image (Text) → URL gambar produk
pickup_start (Time) → Waktu mulai pengambilan
pickup_end (Time) → Batas akhir pengambilan
status (Text) → Status produk (available, reserved, sold)
created_at (Timestamp) → Waktu produk dibuat
📦 4. Tabel orders
id (UUID, Primary Key) → ID unik transaksi
buyer_id (UUID, Foreign Key) → Relasi ke users.id (pembeli)
total_price (Numeric) → Total harga seluruh item
status (Text) → Status order (pending_payment, paid, ready_for_pickup, completed)
payment_status (Text) → Status pembayaran (unpaid, waiting_verification, verified)
pickup_code (Text, Unique) → Kode unik untuk pengambilan barang
created_at (Timestamp) → Waktu transaksi dibuat
🧾 5. Tabel order_items
id (UUID, Primary Key) → ID unik item dalam order
order_id (UUID, Foreign Key) → Relasi ke orders.id
product_id (UUID, Foreign Key) → Relasi ke products.id
quantity (Integer) → Jumlah produk yang dibeli
price (Numeric) → Harga produk saat transaksi
💳 6. Tabel payments
id (UUID, Primary Key) → ID unik pembayaran
order_id (UUID, Foreign Key) → Relasi ke orders.id
method (Text) → Metode pembayaran (default: transfer)
payment_proof (Text) → URL bukti transfer (gambar)
status (Text) → Status pembayaran (pending, verified, rejected)
created_at (Timestamp) → Waktu pembayaran dilakukan
🔥 Catatan Penting (Biar Aman Saat Implementasi)
pickup_code harus unique → untuk validasi saat ambil barang
order_items wajib ada → supaya support cart
merchants memecahkan masalah redundansi lokasi
payments terpisah → biar fleksibel kalau nanti pakai payment gateway
🎯 Ringkasan Singkat
users → akun
merchants → toko
products → barang
orders → transaksi
order_items → detail belanja
payments → pembayaran

Setup Supabase

🔐 1. ROW LEVEL SECURITY (RLS)
alter table users enable row level security;
alter table merchants enable row level security;
alter table products enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table payments enable row level security;

👤 USERS POLICY
User hanya bisa lihat & edit dirinya sendiri
-- SELECT
create policy "Users can view own profile"
on users for select
using (auth.uid() = id);

-- INSERT (dari trigger, jadi tetap allow)
create policy "Users can insert own profile"
on users for insert
with check (auth.uid() = id);

-- UPDATE
create policy "Users can update own profile"
on users for update
using (auth.uid() = id);

🏪 MERCHANTS POLICY
User hanya bisa akses tokonya sendiri
-- SELECT
create policy "Merchant can view own store"
on merchants for select
using (auth.uid() = user_id);

-- INSERT
create policy "User can create merchant"
on merchants for insert
with check (auth.uid() = user_id);

-- UPDATE
create policy "Merchant can update own store"
on merchants for update
using (auth.uid() = user_id);

-- DELETE
create policy "Merchant can delete own store"
on merchants for delete
using (auth.uid() = user_id);
🛒 PRODUCTS POLICY
Public bisa lihat, tapi hanya merchant bisa edit
-- SELECT (PUBLIC)
create policy "Anyone can view products"
on products for select
using (true);

-- INSERT
create policy "Merchant can insert product"
on products for insert
with check (
  exists (
    select 1 from merchants
    where merchants.id = merchant_id
    and merchants.user_id = auth.uid()
  )
);

-- UPDATE
create policy "Merchant can update own product"
on products for update
using (
  exists (
    select 1 from merchants
    where merchants.id = merchant_id
    and merchants.user_id = auth.uid()
  )
);

-- DELETE
create policy "Merchant can delete own product"
on products for delete
using (
  exists (
    select 1 from merchants
    where merchants.id = merchant_id
    and merchants.user_id = auth.uid()
  )
);

📦 ORDERS POLICY
User hanya bisa lihat order miliknya
-- SELECT
create policy "User can view own orders"
on orders for select
using (auth.uid() = buyer_id);

-- INSERT
create policy "User can create order"
on orders for insert
with check (auth.uid() = buyer_id);

-- UPDATE (untuk update status)
create policy "User can update own order"
on orders for update
using (auth.uid() = buyer_id);

🧾 ORDER ITEMS POLICY
-- SELECT
create policy "User can view own order items"
on order_items for select
using (
  exists (
    select 1 from orders
    where orders.id = order_id
    and orders.buyer_id = auth.uid()
  )
);

-- INSERT
create policy "User can insert own order items"
on order_items for insert
with check (
  exists (
    select 1 from orders
    where orders.id = order_id
    and orders.buyer_id = auth.uid()
  )
);

💳 PAYMENTS POLICY
-- SELECT
create policy "User can view own payments"
on payments for select
using (
  exists (
    select 1 from orders
    where orders.id = order_id
    and orders.buyer_id = auth.uid()
  )
);

-- INSERT
create policy "User can insert payment"
on payments for insert
with check (
  exists (
    select 1 from orders
    where orders.id = order_id
    and orders.buyer_id = auth.uid()
  )
);

🔥 2. TRIGGER AUTO CREATE USER
🎯 Tujuan:

Saat user register → otomatis masuk ke tabel users

Step 1: Function
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', 'User')
  );
  return new;
end;
$$ language plpgsql security definer;
Step 2: Trigger
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

🧠 Auto generate pickup code
create or replace function generate_pickup_code()
returns trigger as $$
begin
  new.pickup_code := 'LB-' || floor(random() * 9000 + 1000)::text;
  return new;
end;
$$ language plpgsql;
create trigger set_pickup_code
before insert on orders
for each row execute procedure generate_pickup_code();


alter table users
add column phone text;

alter table users
add constraint phone_format_check
check (
  phone is null OR phone ~ '^\+62[0-9]{9,13}$'
);

alter table users
add constraint unique_phone unique (phone);

-- 1. Membuat tabel cart
create table public.cart (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade not null, -- Pastikan public.users ada, atau ganti auth.users
  product_id uuid references public.products(id) on delete cascade not null,
  quantity integer not null default 1 check (quantity > 0),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, product_id) -- Mencegah 1 user punya 2 baris terpisah untuk produk yang sama
);

-- 2. Mengaktifkan RLS
alter table public.cart enable row level security;

-- 3. Membuat Policy (Kebijakan Keamanan)
create policy "Users can view own cart"
on cart for select
using (auth.uid() = user_id);

create policy "Users can insert into own cart"
on cart for insert
with check (auth.uid() = user_id);

create policy "Users can update own cart"
on cart for update
using (auth.uid() = user_id);

create policy "Users can delete from own cart"
on cart for delete
using (auth.uid() = user_id);

-- 4. Membuat fungsi RPC untuk tambah/update keranjang
create or replace function add_to_cart(p_product_id uuid, p_quantity integer default 1)
returns void as $$
begin
  insert into public.cart (user_id, product_id, quantity)
  values (auth.uid(), p_product_id, p_quantity)
  on conflict (user_id, product_id)
  do update set 
    quantity = cart.quantity + p_quantity,
    created_at = now();
end;
$$ language plpgsql security definer;

CREATE TABLE IF NOT EXISTS chats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    buyer_id UUID REFERENCES auth.users(id),
    merchant_id UUID REFERENCES merchants(id),
    last_message TEXT,
    unread_buyer INT DEFAULT 0,
    unread_merchant INT DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(buyer_id, merchant_id)
);
CREATE TABLE IF NOT EXISTS messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    chat_id UUID REFERENCES chats(id) ON DELETE CASCADE,
    sender_id UUID,
    content TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "participant_select_chats" ON chats FOR SELECT USING (
    buyer_id = auth.uid() OR merchant_id IN (SELECT id FROM merchants WHERE user_id = auth.uid())
);
CREATE POLICY "buyer_insert_chats" ON chats FOR INSERT WITH CHECK ( buyer_id = auth.uid() );
CREATE POLICY "participant_update_chats" ON chats FOR UPDATE USING (
    buyer_id = auth.uid() OR merchant_id IN (SELECT id FROM merchants WHERE user_id = auth.uid())
);
CREATE POLICY "participant_select_messages" ON messages FOR SELECT USING (
    chat_id IN (SELECT id FROM chats WHERE buyer_id = auth.uid() OR merchant_id IN (SELECT id FROM merchants WHERE user_id = auth.uid()))
);
CREATE POLICY "sender_insert_messages" ON messages FOR INSERT WITH CHECK (
    sender_id = auth.uid()
);