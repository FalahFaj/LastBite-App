import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lastbite/core/providers/update_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    final minDelay = Future.delayed(const Duration(milliseconds: 1500));
    
    AppUpdateInfo? updateInfo;
    try {
      updateInfo = await ref.read(updateProvider.future);
    } catch (e) {
      debugPrint('Gagal mengecek update: $e');
    }

    await minDelay;
    
    if (!mounted) return;

    if (updateInfo != null && updateInfo.updateAvailable) {
      _showUpdateDialog(updateInfo);
    } else {
      context.go('/home');
    }
  }

  void _showUpdateDialog(AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: !info.isForceUpdate,
      builder: (context) {
        return _UpdateDialog(info: info);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_splash.png',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 125),
              child: Image.asset(
                'assets/images/loga_splash.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;

  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  Future<void> _startDownload(String url) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final directory = await getTemporaryDirectory();
      final savePath = '${directory.path}/lastbite_update.apk';
      
      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
      
      final result = await OpenFile.open(savePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka file: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download gagal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.info.isForceUpdate,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Update Tersedia!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Versi terbaru (${widget.info.latestVersionName}) telah rilis.\n\n${widget.info.releaseNotes}',
              style: const TextStyle(height: 1.5),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.grey.shade300,
                color: const Color(0xFF2E7D32),
              ),
              const SizedBox(height: 8),
              Text(
                'Mengunduh... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ]
          ],
        ),
        actions: [
          if (!_isDownloading) ...[
            if (!widget.info.isForceUpdate) ...[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/home');
                },
                child: const Text('Nanti Saja', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => _startDownload(widget.info.downloadUrl),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Update Sekarang'),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _startDownload(widget.info.downloadUrl),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Update Sekarang'),
                ),
              ),
            ]
          ]
        ],
      ),
    );
  }
}
