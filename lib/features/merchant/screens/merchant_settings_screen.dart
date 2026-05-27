import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

class MerchantSettingsScreen extends StatefulWidget {
  const MerchantSettingsScreen({super.key});
  @override
  State<MerchantSettingsScreen> createState() => _MerchantSettingsScreenState();
}

class _MerchantSettingsScreenState extends State<MerchantSettingsScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _notifEnabled = true;
  bool _holidayMode = false;

  String? _merchantId;
  String _storeName = '';
  String _description = '';
  String _location = '';
  String? _avatarUrl;

  final _storeNameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  final List<String> _locations = [
    'Sumbersari', 'Kaliwates', 'Patrang', 'Ajung', 'Arjasa'
  ];
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final m = await supabase
          .from('merchants')
          .select('id, store_name, avatar_url, location')
          .eq('user_id', user.id)
          .maybeSingle();
      if (m != null && mounted) {
        _merchantId = m['id'] as String?;
        final loc = m['location'] as String? ?? '';
        setState(() {
          _storeName = m['store_name'] as String? ?? '';
          _avatarUrl = m['avatar_url'] as String?;
          _location = loc;
          _selectedLocation = _locations.contains(loc) ? loc : null;
        });
        _storeNameCtrl.text = _storeName;
        try {
          final extra = await supabase
              .from('merchants')
              .select('description')
              .eq('id', _merchantId!)
              .single();
          _description = extra['description'] as String? ?? '';
          _descCtrl.text = _description;
        } catch (_) {}
      }

      // Load SharedPreferences for toggles
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _notifEnabled = prefs.getBool('notif_enabled_$_merchantId') ?? true;
          _holidayMode = prefs.getBool('holiday_mode_$_merchantId') ?? false;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleNotif(bool value) async {
    setState(() => _notifEnabled = value);
    if (_merchantId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_enabled_$_merchantId', value);
    }
  }

  Future<void> _toggleHoliday(bool value) async {
    setState(() => _holidayMode = value);
    if (_merchantId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('holiday_mode_$_merchantId', value);
    }
  }

  // ── WhatsApp CS ──
  Future<void> _contactCS() async {
    const phone = '6287863306466';
    const msg = 'Halo CS LastBite, saya membutuhkan bantuan.';
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

  // ── Edit Profil & Info Toko sheet ──
  void _showEditProfilSheet() {
    _storeNameCtrl.text = _storeName;
    _descCtrl.text = _description;
    String? tempLoc = _selectedLocation;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  const Text('Profil & Info Toko',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                  const SizedBox(height: 4),
                  const Text('Perbarui informasi toko kamu',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 20),

                  // Nama Toko
                  const Text('Nama Toko', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _storeNameCtrl,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: InputBorder.none,
                        hintText: 'Masukkan nama toko...',
                        hintStyle: TextStyle(color: Color(0xFFD1D5DB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lokasi
                  const Text('Lokasi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: tempLoc,
                        hint: const Text('Pilih lokasi...', style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 14)),
                        items: _locations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                        onChanged: (v) => setSheetState(() => tempLoc = v),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Deskripsi
                  const Text('Deskripsi Toko', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _descCtrl,
                      maxLines: 4,
                      maxLength: 300,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(14),
                        border: InputBorder.none,
                        hintText: 'Ceritakan keunikan toko kamu...',
                        hintStyle: TextStyle(color: Color(0xFFD1D5DB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: () => _saveProfilInfo(tempLoc),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white,
                        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Simpan Perubahan',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfilInfo(String? loc) async {
    if (_merchantId == null) return;
    if (_storeNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nama toko tidak boleh kosong!'),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    try {
      // 1. Update basic info (selalu ada kolomnya)
      final updateData = {'store_name': _storeNameCtrl.text.trim()};
      if (loc != null) updateData['location'] = loc;
      await supabase.from('merchants').update(updateData).eq('id', _merchantId!);

      // 2. Coba update description (jika kolom ada, kalau belum ada akan catch)
      try {
        await supabase
            .from('merchants')
            .update({'description': _descCtrl.text.trim()}).eq('id', _merchantId!);
      } catch (_) {} // Abaikan jika kolom description tidak ada di Supabase

      if (mounted) {
        setState(() {
          _storeName = _storeNameCtrl.text.trim();
          _description = _descCtrl.text.trim();
          _location = loc ?? _location;
          _selectedLocation = loc;
        });
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(SolarIconsOutline.checkCircle, color: Colors.white),
            SizedBox(width: 8),
            Text('Profil toko berhasil diperbarui!', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: Color(0xFF16A34A), behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menyimpan profil: $e'),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Syarat & Ketentuan modal ──
  void _showTermsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TermsSheet(),
    );
  }

  // ── Rekening Pencairan placeholder ──
  void _showRekeningSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SimpleSheet(
        title: 'Rekening Pencairan',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoTile(SolarIconsOutline.banknote, const Color(0xFF16A34A),
                'Bank BCA', '1234567890 – a.n. Pemilik Toko'),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoTile(SolarIconsOutline.wallet, const Color(0xFF2563EB),
                'GoPay / OVO', 'Belum ditautkan'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9EC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                '📌 Fitur pencairan dana akan segera tersedia. Hubungi CS LastBite untuk informasi lebih lanjut.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, Color color, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          Text(sub,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ]),
      ]),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar dari Akun?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Kamu akan keluar dari akun LastBite Mitra.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF6B7280)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Keluar',
                  style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true) return;
    await supabase.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F5),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
            : Column(children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileHeader(),
                        const SizedBox(height: 20),
                        _buildSection('PENGELOLAAN TOKO', [
                          _buildTile(
                            icon: SolarIconsOutline.shop,
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF16A34A),
                            title: 'Profil & Info Toko',
                            subtitle: 'Ubah nama, deskripsi, dan foto toko',
                            onTap: _showEditProfilSheet,
                          ),
                          _buildDivider(),
                          _buildTile(
                            icon: SolarIconsOutline.banknote,
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF16A34A),
                            title: 'Rekening Pencairan',
                            subtitle: 'Kelola bank & e-wallet untuk pendapatan',
                            onTap: _showRekeningSheet,
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _buildSection('PREFERENSI LASTBITE', [
                          _buildToggleTile(
                            icon: SolarIconsOutline.bell,
                            iconBg: const Color(0xFF1F1F1F),
                            iconColor: Colors.white,
                            title: 'Notifikasi Pesanan Baru',
                            subtitle: 'Tampilkan notifikasi saat ada pembeli',
                            value: _notifEnabled,
                            onChanged: _toggleNotif,
                          ),
                          _buildDivider(),
                          _buildToggleTile(
                            icon: SolarIconsOutline.umbrella,
                            iconBg: const Color(0xFFFFF7ED),
                            iconColor: const Color(0xFFEA580C),
                            title: 'Mode Libur',
                            subtitle: 'Jeda jualan sementara agar tidak ada pesan',
                            value: _holidayMode,
                            onChanged: _toggleHoliday,
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _buildSection('PUSAT BANTUAN & EDUKASI', [
                          _buildTile(
                            icon: SolarIconsOutline.headphonesRound,
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF16A34A),
                            title: 'Hubungi CS LastBite',
                            subtitle: 'Bantuan cepat 24/7 untuk kendala toko',
                            onTap: _contactCS,
                          ),
                          _buildDivider(),
                          _buildTile(
                            icon: SolarIconsOutline.document,
                            iconBg: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                            title: 'Syarat & Ketentuan Mitra',
                            subtitle: 'Kebijakan penggunaan aplikasi bagi penjual',
                            onTap: _showTermsSheet,
                          ),
                        ]),
                        const SizedBox(height: 32),
                        _buildLogoutButton(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ]),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.go('/merchant/store-profile'),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: const Icon(SolarIconsOutline.altArrowLeft, size: 16, color: Color(0xFF374151)),
          ),
        ),
        const SizedBox(width: 14),
        const Text('Pengaturan Toko',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
      ]),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E7EB), width: 2)),
          child: ClipOval(
            child: _avatarUrl != null
                ? Image.network(_avatarUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _avatarPlaceholder())
                : _avatarPlaceholder(),
          ),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_storeName.isEmpty ? 'Nama Toko' : _storeName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(SolarIconsOutline.verifiedCheck, size: 13, color: Colors.white),
              SizedBox(width: 4),
              Text('Mitra LastBite',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _avatarPlaceholder() => Container(
      color: const Color(0xFFECFDF5),
      child: const Icon(SolarIconsBold.user, size: 28, color: Color(0xFF16A34A)));

  Widget _buildSection(String label, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF), letterSpacing: 0.6)),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: children),
      ),
    ]);
  }

  Widget _buildTile({
    required IconData icon, required Color iconBg, required Color iconColor,
    required String title, required String subtitle, required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          ])),
          const Icon(SolarIconsOutline.altArrowRight, color: Color(0xFFD1D5DB), size: 20),
        ]),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon, required Color iconBg, required Color iconColor,
    required String title, required String subtitle,
    required bool value, required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF16A34A),
        ),
      ]),
    );
  }

  Widget _buildDivider() =>
      const Divider(height: 1, indent: 70, endIndent: 16, color: Color(0xFFF3F4F6));

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity, height: 52,
        child: OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(SolarIconsOutline.logout_3, color: Color(0xFFEF4444), size: 18),
          label: const Text('Keluar dari Akun',
              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 15)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }
}


// ── Simple Wrapper Sheet ──
class _SimpleSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _SimpleSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        const SizedBox(height: 16),
        child,
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ── Syarat & Ketentuan Sheet ──
class _TermsSheet extends StatelessWidget {
  const _TermsSheet();

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
              child: Text('Syarat & Ketentuan Mitra',
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
                        'Dengan mendaftarkan diri sebagai Mitra LastBite, Anda menyetujui seluruh syarat dan ketentuan yang berlaku. LastBite berhak mengubah ketentuan ini sewaktu-waktu dengan pemberitahuan terlebih dahulu.',
                  ),
                  _TermsSection(
                    number: '2',
                    title: 'Kewajiban Mitra',
                    content:
                        '• Menyajikan produk makanan yang layak konsumsi dan sesuai deskripsi.\n• Memproses pesanan tepat waktu sesuai jadwal pickup.\n• Menjaga kebersihan dan keamanan produk.\n• Tidak menjual produk yang sudah kadaluarsa.',
                  ),
                  _TermsSection(
                    number: '3',
                    title: 'Komisi & Pembayaran',
                    content:
                        'LastBite mengenakan komisi sebesar 10% dari setiap transaksi yang berhasil. Pencairan dana dilakukan setiap minggu ke rekening yang telah didaftarkan.',
                  ),
                  _TermsSection(
                    number: '4',
                    title: 'Penangguhan Akun',
                    content:
                        'LastBite berhak menangguhkan atau menghapus akun Mitra yang:\n• Menerima lebih dari 3 komplain valid dalam 30 hari.\n• Membatalkan pesanan tanpa alasan yang jelas lebih dari 5 kali.\n• Melanggar ketentuan produk yang boleh dijual.',
                  ),
                  _TermsSection(
                    number: '5',
                    title: 'Privasi Data',
                    content:
                        'Data Mitra akan digunakan untuk keperluan operasional platform LastBite dan tidak akan dibagikan kepada pihak ketiga tanpa persetujuan Mitra.',
                  ),
                  _TermsSection(
                    number: '6',
                    title: 'Misi Lingkungan',
                    content:
                        'Sebagai Mitra LastBite, Anda turut berkontribusi dalam mengurangi pemborosan makanan. Setiap porsi yang berhasil dijual membantu mengurangi emisi karbon dan food waste di Indonesia.',
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
