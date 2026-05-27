import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/cloudinary_service.dart';
import 'package:solar_icons/solar_icons.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? productToEdit;
  const AddProductScreen({super.key, this.productToEdit});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _inputPriceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;

  TimeOfDay? _selectedTime;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _loadingStatus = '';

  String? _existingImageUrl;

  bool _isFoodCategory() {
    if (_selectedCategoryId == null) return false;
    final cat = _categories.firstWhere(
      (c) => c['id'].toString() == _selectedCategoryId,
      orElse: () => {},
    );
    final name = (cat['name'] as String? ?? '').toLowerCase();
    return name.contains('makan');
  }

  int _computeSellingPrice(int basePrice) {
    return (_isFoodCategory() ? basePrice * 1.10 : basePrice * 1.15).round();
  }

  int _computeOriginalPrice(int sellingPrice) {
    final random = Random();
    final multiplier = 1.3 + (random.nextDouble() * 0.7);
    
    double original = sellingPrice * multiplier;
    
    // Bulatkan ke ratusan terdekat agar harga lebih rapi (contoh: 21345 -> 21300)
    return (original / 100).round() * 100;
  }

  int _deriveBasePrice(int dbPrice) {
    return _isFoodCategory()
        ? (dbPrice / 1.10).round()
        : (dbPrice / 1.15).round();
  }

  @override
  void initState() {
    super.initState();
    _fetchCategories().then((_) {
      if (widget.productToEdit != null) {
        _prefillData(widget.productToEdit!);
      }
    });
  }

  void _prefillData(Map<String, dynamic> product) {
    _nameController.text = product['name'] ?? '';
    _descController.text = product['description'] ?? '';
    _stockController.text = (product['stock'] ?? 0).toString();

    if (product['category_id'] != null) {
      _selectedCategoryId = product['category_id'].toString();
    }

    _existingImageUrl = product['image'];

    if (product['pickup_end'] != null) {
      final timeParts = product['pickup_end'].toString().split(':');
      if (timeParts.length >= 2) {
        _selectedTime = TimeOfDay(
          hour: int.tryParse(timeParts[0]) ?? 0,
          minute: int.tryParse(timeParts[1]) ?? 0,
        );
      }
    }

    final int dbPrice = product['price'] ?? 0;
    _inputPriceController.text = _deriveBasePrice(dbPrice).toString();
    setState(() {});
  }

  Future<void> _fetchCategories() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase.from('categories').select('id, name');
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    // Tampilkan pilihan: Kamera atau Galeri
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1DDD1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Pilih Sumber Foto',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D312E),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(
                    SolarIconsOutline.camera,
                    color: Color(0xFF0F9D58),
                  ),
                ),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(
                    SolarIconsOutline.gallery,
                    color: Color(0xFF0F9D58),
                  ),
                ),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70, // Kompresi layer 1: sebelum upload ke Cloudinary
      maxWidth: 1200, // Batasi resolusi maksimal sebelum upload
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih kategori produk')));
      return;
    }

    if (_isFoodCategory() && _selectedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih batas pengambilan')));
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingStatus = _imageFile != null
          ? 'Mengupload foto...'
          : 'Menyimpan produk...';
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) throw 'Harap login terlebih dahulu';

      final merchantRes = await supabase
          .from('merchants')
          .select('id')
          .eq('user_id', user.id)
          .single();
      final merchantId = merchantRes['id'];

      String? imageUrl = _existingImageUrl;
      if (_imageFile != null) {
        setState(() => _loadingStatus = 'Mengupload foto ke Cloudinary...');
        imageUrl = await CloudinaryService.uploadImage(
          _imageFile!,
          folder: 'products',
        );
        setState(() => _loadingStatus = 'Menyimpan produk...');
      }

      final cleanInputPrice = _inputPriceController.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final cleanStock = _stockController.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      final int basePrice = int.tryParse(cleanInputPrice) ?? 0;
      final int sellingPrice = _computeSellingPrice(basePrice);
      
      int originalPrice;
      if (widget.productToEdit != null && 
          widget.productToEdit!['price'] == sellingPrice && 
          widget.productToEdit!['original_price'] != null) {
        // Pertahankan harga coret lama jika harga jual tidak diubah saat edit
        originalPrice = widget.productToEdit!['original_price'] as int;
      } else {
        originalPrice = _computeOriginalPrice(sellingPrice);
      }

      final productData = {
        'merchant_id': merchantId,
        'category_id': _selectedCategoryId,
        'name': _nameController.text,
        'description': _descController.text,
        'original_price': originalPrice,
        'price': sellingPrice,
        'stock': int.tryParse(cleanStock) ?? 0,
        'pickup_end': _isFoodCategory() && _selectedTime != null
            ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00'
            : null,
        'image': imageUrl,
        'status': 'available',
      };

      if (widget.productToEdit != null) {
        productData['updated_at'] = DateTime.now().toUtc().toIso8601String();
        await supabase
            .from('products')
            .update(productData)
            .eq('id', widget.productToEdit!['id']);
      } else {
        await supabase.from('products').insert(productData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.productToEdit != null
                  ? 'Produk berhasil diperbarui!'
                  : 'Produk berhasil ditambahkan!',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingStatus = '';
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _inputPriceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            SolarIconsOutline.altArrowLeft,
            color: Color(0xFF2D312E),
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.productToEdit != null ? 'Ubah Produk' : 'Tambah Produk',
          style: const TextStyle(
            color: Color(0xFF2D312E),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE8F0E8), height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kategori Produk',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D312E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        items: _categories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat['id'].toString(),
                            child: Text(cat['name']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategoryId = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Pilih Kategori Terlebih Dahulu',
                          hintStyle: const TextStyle(
                            color: Color(0xFFA0A9A0),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1DDD1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1DDD1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF0F9D58),
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null) {
                            return 'Wajib pilih kategori';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      if (_selectedCategoryId != null) ...[
                        InkWell(
                          onTap: _pickImage,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            height: 180,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF0F9D58).withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: _imageFile != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.file(
                                      _imageFile!,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : _existingImageUrl != null &&
                                      _existingImageUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      _existingImageUrl!,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          SolarIconsOutline.cameraAdd,
                                          color: Color(0xFF0F9D58),
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Unggah Foto Produk',
                                        style: TextStyle(
                                          color: Color(0xFF0F9D58),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Format .jpg atau .png maksimal 5MB',
                                        style: TextStyle(
                                          color: Color(0xFF8A938C),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildSectionTitle(
                          _isFoodCategory()
                              ? 'Informasi Makanan'
                              : 'Informasi Barang',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: _isFoodCategory()
                              ? 'Nama Makanan'
                              : 'Nama Barang',
                          hint: _isFoodCategory()
                              ? 'Contoh: Roti Sourdough Sisa Hari Ini'
                              : 'Contoh: Sayuran Sisa',
                          controller: _nameController,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Deskripsi',
                          hint: 'Jelaskan kondisi barang saat ini...',
                          controller: _descController,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 32),
                        _buildSectionTitle('Detail Penjualan'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Harga Jual yang Diinginkan',
                          hint: '0',
                          controller: _inputPriceController,
                          keyboardType: TextInputType.number,
                          prefixText: 'Rp ',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildTextField(
                                label: 'Stok Tersedia',
                                hint: '0',
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            if (_isFoodCategory()) ...[
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Batas Pengambilan',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2D312E),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFD1DDD1),
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => _selectTime(context),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _selectedTime != null
                                                    ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                                                    : 'Pilih Waktu',
                                                style: TextStyle(
                                                  color: _selectedTime != null
                                                      ? const Color(0xFF2D312E)
                                                      : const Color(0xFFA0A9A0),
                                                  fontSize: 14,
                                                  fontWeight:
                                                      _selectedTime != null
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                              const Icon(
                                                SolarIconsOutline.clockCircle,
                                                color: Color(0xFF8A938C),
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_selectedCategoryId != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F9D58),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _loadingStatus,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            widget.productToEdit != null
                                ? 'Simpan Perubahan'
                                : 'Simpan Produk',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFF2D312E),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D312E),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: Color(0xFF2D312E)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFA0A9A0), fontSize: 14),
            prefixText: prefixText,
            prefixStyle: const TextStyle(
              color: Color(0xFF2D312E),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1DDD1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1DDD1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF0F9D58),
                width: 1.5,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Wajib diisi';
            }
            return null;
          },
        ),
      ],
    );
  }
}
