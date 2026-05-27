import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lastbite/core/services/cloudinary_service.dart';

import 'package:solar_icons/solar_icons.dart';

class MerchantStoreProfileScreen extends StatefulWidget {
  const MerchantStoreProfileScreen({super.key});
  @override
  State<MerchantStoreProfileScreen> createState() =>
      _MerchantStoreProfileScreenState();
}

class _MerchantStoreProfileScreenState
    extends State<MerchantStoreProfileScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _merchantId;

  // Foto profil (bulat)
  String? _avatarUrl;
  File? _avatarFile;
  bool _isUploadingAvatar = false;

  // Banner toko (landscape)
  String? _bannerUrl;
  File? _bannerFile;
  bool _isUploadingBanner = false;

  String _storeName = '';
  String _location = '';
  String _description = '';
  int _totalOrders = 0;
  double _rating = 4.9;
  int _totalReviews = 128;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final merchant = await supabase
          .from('merchants')
          .select('id, store_name, owner_name, office_phone, location')
          .eq('user_id', user.id)
          .maybeSingle();
      if (merchant == null) return;

      _merchantId = merchant['id'] as String;
      _storeName = merchant['store_name'] as String? ?? '';
      _location = merchant['location'] as String? ?? '';

      try {
        final extra = await supabase
            .from('merchants')
            .select('avatar_url, banner_url, description')
            .eq('id', _merchantId!)
            .single();
        _avatarUrl = extra['avatar_url'] as String?;
        _bannerUrl = extra['banner_url'] as String?;
        _description = extra['description'] as String? ?? '';
      } catch (_) {}

      final orders = await supabase
          .from('orders')
          .select('id, order_items(products(merchant_id))')
          .not('status', 'in', '(cancelled)');
      _totalOrders = (orders as List).where((o) {
        final items = o['order_items'] as List? ?? [];
        return items.any(
            (i) => (i['products'] as Map?)?['merchant_id'] == _merchantId);
      }).length;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal memuat data: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<ImageSource?> _showSourceSheet(String title) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(SolarIconsOutline.camera,
                  color: Color(0xFF16A34A)),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(SolarIconsOutline.gallery,
                  color: Color(0xFF16A34A)),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final source = await _showSourceSheet('Ganti Foto Profil');
    if (source == null) return;
    final file = await ImagePicker()
        .pickImage(source: source, imageQuality: 75, maxWidth: 600);
    if (file == null) return;
    setState(() {
      _avatarFile = File(file.path);
      _isUploadingAvatar = true;
    });
    try {
      final url = await CloudinaryService.uploadImage(_avatarFile!);
      if (mounted) {
        setState(() => _avatarUrl = url);
        await supabase
            .from('merchants')
            .update({'avatar_url': url}).eq('id', _merchantId!);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal upload foto profil: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _pickBanner() async {
    final source = await _showSourceSheet('Ganti Banner Toko');
    if (source == null) return;
    final file = await ImagePicker()
        .pickImage(source: source, imageQuality: 75, maxWidth: 1200);
    if (file == null) return;
    setState(() {
      _bannerFile = File(file.path);
      _isUploadingBanner = true;
    });
    try {
      final url = await CloudinaryService.uploadImage(_bannerFile!);
      if (mounted) {
        setState(() => _bannerUrl = url);
        await supabase
            .from('merchants')
            .update({'banner_url': url}).eq('id', _merchantId!);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal upload banner: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
    } finally {
      if (mounted) setState(() => _isUploadingBanner = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      extendBody: true,

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF16A34A)))
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: _buildBannerAndAvatar(),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileInfo(),
                        const SizedBox(height: 20),
                        _buildStatsCard(),
                        const SizedBox(height: 20),
                        _buildPengaturanButton(),
                        const SizedBox(height: 16),
                        _buildMotivationCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ─────────────────────────── AppBar ───────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFFF9FAF9),
      surfaceTintColor: const Color(0xFFF9FAF9),
      automaticallyImplyLeading: false,
      actions: [
        GestureDetector(
          onTap: () {},
          child: Container(
            margin: const EdgeInsets.only(right: 20),
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFFBF4E4),
              shape: BoxShape.circle,
            ),
            child: const Icon(SolarIconsOutline.share,
                size: 20, color: Color(0xFF3B382D)),
          ),
        ),
      ],
      titleSpacing: 20,
      title: const Text(
        'Profil Toko',
        style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF3B382D)),
      ),
      centerTitle: false,
    );
  }

  Widget _buildBannerAndAvatar() {
    return SizedBox(
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
            // ── Banner (landscape) ──
            Positioned.fill(
              bottom: 36,
              child: GestureDetector(
                onTap: _pickBanner,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _bannerFile != null
                        ? Image.file(_bannerFile!, fit: BoxFit.cover)
                        : _bannerUrl != null
                            ? Image.network(_bannerUrl!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _defaultBanner())
                            : _defaultBanner(),
                    if (_isUploadingBanner)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5)),
                      ),
                    if (!_isUploadingBanner)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(SolarIconsOutline.camera,
                                  size: 12, color: Colors.white),
                              SizedBox(width: 5),
                              Text('Ganti Banner',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // ── Area putih melengkung bawah banner ──
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAF9),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(22)),
                ),
              ),
            ),
            // ── Foto profil bulat (overlap) ──
            Positioned(
              left: 20,
              bottom: 0,
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: _isUploadingAvatar
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF16A34A), strokeWidth: 2))
                          : ClipOval(
                              child: _avatarFile != null
                                  ? Image.file(_avatarFile!,
                                      fit: BoxFit.cover, width: 72, height: 72)
                                  : _avatarUrl != null && _avatarUrl!.isNotEmpty
                                      ? Image.network(
                                          _avatarUrl!,
                                          fit: BoxFit.cover,
                                          width: 72,
                                          height: 72,
                                          errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
                                        )
                                      : _buildFallbackAvatar(),
                            ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(SolarIconsOutline.camera,
                            size: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _defaultBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14532D), Color(0xFF166534)],
        ),
      ),
      child: const Center(
        child: Icon(SolarIconsBold.shop,
            color: Colors.white24, size: 64),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    final name = _storeName.isNotEmpty ? Uri.encodeComponent(_storeName) : 'Toko';
    return Image.network(
      'https://ui-avatars.com/api/?name=$name&background=16A34A&color=fff&size=150',
      fit: BoxFit.cover,
      width: 72,
      height: 72,
    );
  }

  // ─────────────────────────── Info Toko ───────────────────────────
  Widget _buildProfileInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                _storeName.isEmpty ? 'Nama Toko' : _storeName,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                  color: Color(0xFF16A34A), shape: BoxShape.circle),
              child: const Icon(SolarIconsOutline.checkCircle,
                  size: 13, color: Colors.white),
            ),
          ],
        ),
        if (_location.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(SolarIconsOutline.mapPoint,
                  size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text(_location,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (_description.isNotEmpty)
          Text(
            _description,
            style: const TextStyle(
                fontSize: 13.5, color: Color(0xFF6B7280), height: 1.55),
          )
        else
          Text(
            'Spesialis masakan pilihan yang enak, higienis, dan ramah di kantong! Yuk, selamatkan makanan bersisa hari ini dan bantu jaga bumi kita. 🌍💚',
            style: const TextStyle(
                fontSize: 13.5, color: Color(0xFF6B7280), height: 1.55),
          ),
      ],
    );
  }

  // ─────────────────────────── Stats 3 kolom ───────────────────────────
  Widget _buildStatsCard() {
    final co2 = (_totalOrders * 0.5);
    final co2Text = co2 >= 1
        ? '${co2.toStringAsFixed(0)} kg'
        : '${(_totalOrders * 500).toStringAsFixed(0)} g';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          _statItem(
            icon: SolarIconsOutline.leaf,
            value: co2Text,
            label: 'CO2 Dicegah',
          ),
          _divider(),
          _statItem(
            icon: SolarIconsOutline.star,
            value: '${_rating.toStringAsFixed(1)} / 5.0',
            label: '$_totalReviews Ulasan',
          ),
          _divider(),
          _statItem(
            icon: SolarIconsOutline.hamburgerMenu,
            value: '${_totalOrders > 0 ? _totalOrders : 450}+',
            label: 'Porsi Selamat',
          ),
        ],
      ),
    );
  }

  Widget _statItem(
      {required IconData icon,
      required String value,
      required String label}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF16A34A)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827))),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 40, color: const Color(0xFFF3F4F6));

  // ─────────────────────────── Pengaturan Button ───────────────────────────
  Widget _buildPengaturanButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => context.push('/merchant/settings'),
        icon: const Icon(SolarIconsOutline.settings, size: 20),
        label: const Text('Pengaturan',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ─────────────────────────── Motivation Card ───────────────────────────
  Widget _buildMotivationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFCF2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Kamu membangun perubahan! ',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827))),
              Text('🌱', style: TextStyle(fontSize: 14)),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Terima kasih sudah memberi produkmu kesempatan kedua!\nSetiap pesanan yang kamu proses selalu berarti.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5, color: Color(0xFF9CA3AF), height: 1.5),
          ),
        ],
      ),
    );
  }
}

