import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:solar_icons/solar_icons.dart';

class UserAddressScreen extends StatefulWidget {
  const UserAddressScreen({super.key});

  @override
  State<UserAddressScreen> createState() => _UserAddressScreenState();
}

class _UserAddressScreenState extends State<UserAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  bool _isSaving = false;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userData = await supabase
          .from('users')
          .select('address, latitude, longitude')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (userData != null) {
            _addressController.text = userData['address'] ?? '';
            if (userData['latitude'] != null) {
              _latitude = (userData['latitude'] as num).toDouble();
            }
            if (userData['longitude'] != null) {
              _longitude = (userData['longitude'] as num).toDouble();
            }
          }
          _isFetching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat alamat: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // 1. Cek apakah layanan GPS aktif
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Layanan lokasi tidak aktif. Harap nyalakan GPS Anda.';
      }

      // 2. Cek izin lokasi
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Izin lokasi ditolak.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Izin lokasi ditolak secara permanen. Harap izinkan melalui pengaturan perangkat.';
      }

      // 3. Dapatkan koordinat
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Titik koordinat berhasil didapatkan!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade600),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap dapatkan titik koordinat lokasi Anda terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw 'Sesi berakhir, harap login ulang.';

      await supabase.from('users').update({
        'address': _addressController.text,
        'latitude': _latitude,
        'longitude': _longitude,
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alamat berhasil disimpan!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan alamat: $e'), backgroundColor: Colors.red.shade600),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAF9),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Icon(SolarIconsOutline.altArrowLeft, color: Color(0xFF2D312E), size: 20),
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Alamat Pengiriman',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF3B382D)),
        ),
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(SolarIconsOutline.mapPoint, color: Color(0xFF10B981), size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Titik Lokasi Pengiriman',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _latitude != null && _longitude != null
                                      ? 'Lat: ${_latitude!.toStringAsFixed(5)}, Lng: ${_longitude!.toStringAsFixed(5)}'
                                      : 'Titik koordinat belum diatur',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF047857)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                        icon: _isLoadingLocation
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)))
                            : const Icon(SolarIconsOutline.mapPoint, size: 20),
                        label: Text(
                          _isLoadingLocation ? 'Mendapatkan lokasi...' : 'Dapatkan Lokasi Saat Ini',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF16A34A),
                          side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Detail Alamat Lengkap',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2D312E)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 4,
                      validator: (value) => value == null || value.trim().isEmpty ? 'Alamat tidak boleh kosong' : null,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF2D312E)),
                      decoration: InputDecoration(
                        hintText: 'Tuliskan nama jalan, nomor rumah, RT/RW, kelurahan, dan patokan (misal: rumah pagar hitam)',
                        hintStyle: const TextStyle(color: Color(0xFFA0A9A0), fontSize: 14, fontWeight: FontWeight.w400),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE8F0E8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE8F0E8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveAddress,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          disabledBackgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Simpan Alamat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
