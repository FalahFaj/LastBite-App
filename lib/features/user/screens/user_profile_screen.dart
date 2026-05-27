import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lastbite/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:intl/intl.dart';
import 'package:lastbite/features/user/providers/user_stats_provider.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isCheckingMerchant = false;
  bool _infoDiskon = true;
  bool _pengingatWaktu = true;
  bool _isLoadingPreferences = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('users')
          .select('notify_nearby_discounts, notify_expiring_offers')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _infoDiskon = data['notify_nearby_discounts'] ?? true;
          _pengingatWaktu = data['notify_expiring_offers'] ?? true;
        });
      }
    } catch (e) {
      // Silently ignore or log error
    } finally {
      if (mounted) setState(() => _isLoadingPreferences = false);
    }
  }

  Future<void> _updatePreference(String column, bool value) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('users')
          .update({column: value})
          .eq('id', user.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui preferensi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatRp(double value) {
    final formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(value);
  }

  Future<void> _checkGroupAndNavigate() async {
    setState(() {
      _isCheckingMerchant = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) context.go('/login');
        return;
      }

      final response = await Supabase.instance.client
          .from('merchants')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        context.go('/merchant/dashboard');
      } else {
        _showRegisterMerchantDialog(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengecek status mitra: $e', style: const TextStyle(fontWeight: FontWeight.w500)),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingMerchant = false;
        });
      }
    }
  }

  Future<void> _contactCS() async {
    const phone = '6287863306466';
    const msg = 'Halo CS LastBite, saya pengguna dan membutuhkan bantuan.';
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tidak dapat membuka WhatsApp'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showTermsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _UserTermsSheet(),
    );
  }

  void _showRegisterMerchantDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Belum Terdaftar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: const Text('Anda belum terdaftar sebagai mitra (penjual). Apakah Anda ingin mendaftar sekarang?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Kembali', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.go('/register-merchant');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Daftar Jadi Mitra', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['name'] as String? ?? 'Pengguna';
    final userAvatar = user?.userMetadata?['avatar_url'] as String? ?? 'https://ui-avatars.com/api/?name=$userName&background=16A34A&color=fff&size=150';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAF9),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 24,
        title: const Text(
          'Profil Saya',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF3B382D)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: NetworkImage(userAvatar),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF3B382D)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Penyelamat Aktif',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- HERO BANNER ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF16A34A), Color(0xFF147A36), Color(0xFF0F5A28)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                image: const DecorationImage(
                  image: AssetImage('assets/images/banner.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                    ),
                    child: const Icon(SolarIconsOutline.leaf, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ref.watch(userStatsProvider).when(
                      data: (stats) {
                        if (stats.totalPortions == 0) {
                          return const Center(
                            child: Text(
                              'Yuk beli, dan jadilah pahlawan bumi! 🌱',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pahlawan Bumi! 🌱',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            const SizedBox(height: 6),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    height: 1.4,
                                    fontWeight: FontWeight.w400),
                                children: [
                                  const TextSpan(
                                      text: 'Bulan ini kamu menyelamatkan '),
                                  TextSpan(
                                      text: '${stats.totalPortions} porsi',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  const TextSpan(text: ' makanan\ndan hemat '),
                                  TextSpan(
                                      text: _formatRp(stats.totalSavings),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  const TextSpan(text: '. Kerja bagus!'),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white70),
                      ),
                      error: (e, _) => const Text(
                        'Gagal memuat statistik penghematan.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- AKUN SAYA ---
            _buildSectionTitle('AKUN SAYA'),
            _buildMenuContainer(
              children: [
                _buildMenuItem(
                  icon: SolarIconsOutline.user,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: const Color(0xFFECFDF5),
                  title: 'Profil Pribadi',
                  subtitle: 'Ubah nama, email, dan nomor telepon',
                  onTap: () async {
                    final result = await context.push('/edit-profile');
                    if (result == true) {
                      setState(() {});
                    }
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: SolarIconsOutline.shop,
                  iconColor: const Color(0xFF6366F1),
                  iconBgColor: const Color(0xFFEEF2FF),
                  title: 'Dashboard Toko',
                  subtitle: 'Kelola penjualan dan pesanan masuk',
                  trailing: _isCheckingMerchant 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)))
                    : const Icon(SolarIconsOutline.altArrowRight, color: Color(0xFF9CA3AF)),
                  onTap: _isCheckingMerchant ? null : _checkGroupAndNavigate,
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: SolarIconsOutline.mapPoint,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: const Color(0xFFECFDF5),
                  title: 'Alamat Tersimpan',
                  subtitle: 'Kelola alamat rumah atau kantormu',
                  onTap: () => context.push('/user-address'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- PREFERENSI & NOTIFIKASI ---
            _buildSectionTitle('PREFERENSI & NOTIFIKASI'),
            _buildMenuContainer(
              children: [
                _buildMenuItem(
                  icon: SolarIconsOutline.tag,
                  iconColor: const Color(0xFFF59E0B),
                  iconBgColor: const Color(0xFFFEF3C7),
                  title: 'Info Diskon Terdekat',
                  subtitle: 'Dapatkan notifikasi makanan murah di sekitar',
                  trailing: _isLoadingPreferences 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)))
                    : Transform.scale(
                        scale: 0.8,
                        child: CupertinoSwitch(
                          activeTrackColor: const Color(0xFF16A34A),
                          value: _infoDiskon,
                          onChanged: (v) {
                            setState(() => _infoDiskon = v);
                            _updatePreference('notify_nearby_discounts', v);
                          },
                        ),
                      ),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: SolarIconsOutline.clockCircle,
                  iconColor: const Color(0xFFEF4444),
                  iconBgColor: const Color(0xFFFEE2E2),
                  title: 'Pengingat Waktu Habis',
                  subtitle: 'Beri tahu sebelum penawaran berakhir',
                  trailing: _isLoadingPreferences 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)))
                    : Transform.scale(
                        scale: 0.8,
                        child: CupertinoSwitch(
                          activeTrackColor: const Color(0xFF16A34A),
                          value: _pengingatWaktu,
                          onChanged: (v) {
                            setState(() => _pengingatWaktu = v);
                            _updatePreference('notify_expiring_offers', v);
                          },
                        ),
                      ),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: SolarIconsOutline.headphonesRound,
                  iconColor: const Color(0xFFF59E0B),
                  iconBgColor: const Color(0xFFFEF3C7),
                  title: 'Hubungi CS LastBite',
                  subtitle: 'Punya pertanyaan terkait pesananmu?',
                  onTap: _contactCS,
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: SolarIconsOutline.document,
                  iconColor: const Color(0xFFF59E0B),
                  iconBgColor: const Color(0xFFFEF3C7),
                  title: 'Syarat & Ketentuan Pengguna',
                  subtitle: 'Kebijakan penggunaan aplikasi LastBite',
                  onTap: _showTermsSheet,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- KELUAR DARI AKUN ---
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                icon: const Icon(SolarIconsOutline.logout_3, size: 20),
                label: const Text('Keluar dari Akun', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF5252),
                  side: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFA0AAB2), letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildMenuContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8F0E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6), indent: 64, endIndent: 20);
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF3B382D))),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
      ),
      trailing: trailing ?? const Icon(SolarIconsOutline.altArrowRight, color: Color(0xFF9CA3AF)),
      onTap: onTap,
    );
  }
}

// ── Syarat & Ketentuan Pengguna Sheet ──
class _UserTermsSheet extends StatelessWidget {
  const _UserTermsSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Syarat & Ketentuan Pengguna',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
            ),
          ),
          const Divider(height: 24),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TermsSection(
                    number: '1',
                    title: 'Ketentuan Umum',
                    content:
                        'Dengan menggunakan aplikasi LastBite, Anda menyetujui seluruh syarat dan ketentuan yang berlaku. LastBite berhak mengubah ketentuan ini sewaktu-waktu dengan pemberitahuan terlebih dahulu.',
                  ),
                  _TermsSection(
                    number: '2',
                    title: 'Pembelian & Pengambilan',
                    content:
                        '• Pembeli wajib mengambil pesanan sesuai dengan waktu (pickup time) yang telah ditentukan.\n• Pesanan yang tidak diambil pada batas waktu yang ditentukan tidak dapat di-*refund*.\n• Tunjukkan kode pengambilan saat berada di lokasi toko.',
                  ),
                  _TermsSection(
                    number: '3',
                    title: 'Kebijakan Pembatalan',
                    content:
                        'Pembeli dapat membatalkan pesanan selama pesanan tersebut belum diproses (menunggu pembayaran atau menunggu verifikasi). Setelah pesanan diproses atau berstatus Siap Diambil, pesanan tidak dapat dibatalkan.',
                  ),
                  _TermsSection(
                    number: '4',
                    title: 'Kualitas & Alergi',
                    content:
                        'Makanan sisa yang dijual adalah makanan layak konsumsi. LastBite tidak bertanggung jawab atas kondisi alergi tertentu. Pembeli diharapkan membaca deskripsi produk secara saksama sebelum membeli.',
                  ),
                  _TermsSection(
                    number: '5',
                    title: 'Privasi Data',
                    content:
                        'Data Pribadi Anda seperti alamat dan nomor telepon akan digunakan untuk keperluan operasional platform dan koordinasi pesanan, dan tidak akan dibagikan kepada pihak ketiga di luar layanan kami.',
                  ),
                  _TermsSection(
                    number: '6',
                    title: 'Misi Lingkungan',
                    content:
                        'Setiap porsi makanan yang Anda beli turut berkontribusi dalam mengurangi emisi karbon akibat penumpukan sampah makanan di Indonesia. Terima kasih telah menjadi pahlawan bumi! 🌱',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Terakhir diperbarui: 1 Januari 2025',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String number;
  final String title;
  final String content;
  const _TermsSection({required this.number, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 26, height: 26,
            decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
            child: Center(child: Text(number,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        ]),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B7280), height: 1.6)),
      ]),
    );
  }
}
