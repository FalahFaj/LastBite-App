import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static String get _cloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';

  static String get _uploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  static String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  static Future<String> uploadImage(File imageFile, {String? folder}) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      throw Exception(
        'Cloudinary belum dikonfigurasi. '
        'Isi CLOUDINARY_CLOUD_NAME dan CLOUDINARY_UPLOAD_PRESET di file .env',
      );
    }

    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

    request.fields['upload_preset'] = _uploadPreset;
    if (folder != null) {
      request.fields['folder'] = folder;
    }

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return responseData['secure_url'] as String;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        'Upload gagal (${response.statusCode}): '
        '${errorData['error']?['message'] ?? 'Unknown error'}',
      );
    }
  }

  static String getOptimizedUrl(
    String originalUrl, {
    int width = 400,
    int height = 400,
    String crop = 'fill',
  }) {
    if (originalUrl.isEmpty || !originalUrl.contains('cloudinary.com')) {
      return originalUrl;
    }
    return originalUrl.replaceFirst(
      '/upload/',
      '/upload/w_$width,h_$height,c_$crop,q_auto:good,f_auto/',
    );
  }
}

