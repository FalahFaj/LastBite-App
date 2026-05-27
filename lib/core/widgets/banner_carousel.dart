import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lastbite/core/models/banner_model.dart';
import 'package:lastbite/core/services/cloudinary_service.dart';
import 'package:url_launcher/url_launcher.dart';

class BannerCarousel extends StatefulWidget {
  final List<BannerModel> banners;
  final Widget fallbackWidget;

  const BannerCarousel({
    super.key,
    required this.banners,
    required this.fallbackWidget,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _handleBannerTap(BuildContext context, String? actionUrl) async {
    if (actionUrl == null || actionUrl.isEmpty) return;
    
    if (actionUrl.startsWith('/')) {
      context.push(actionUrl);
    } else {
      final uri = Uri.parse(actionUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return widget.fallbackWidget;
    }

    if (widget.banners.length == 1) {
      final banner = widget.banners.first;
      return GestureDetector(
        onTap: () => _handleBannerTap(context, banner.actionUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.network(
            CloudinaryService.getOptimizedUrl(banner.imageUrl, width: 800, height: 400),
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => widget.fallbackWidget,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 180, // Adjustable height for banner
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return GestureDetector(
                onTap: () => _handleBannerTap(context, banner.actionUrl),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      CloudinaryService.getOptimizedUrl(banner.imageUrl, width: 800, height: 400),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => widget.fallbackWidget,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.banners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: _currentPage == index ? 24 : 8,
              decoration: BoxDecoration(
                color: _currentPage == index ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
