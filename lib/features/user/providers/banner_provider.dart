import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lastbite/core/models/banner_model.dart';

final bannersProvider = AsyncNotifierProvider<BannersNotifier, List<BannerModel>>(() {
  return BannersNotifier();
});

class BannersNotifier extends AsyncNotifier<List<BannerModel>> {
  @override
  Future<List<BannerModel>> build() async {
    return _fetchBanners();
  }

  Future<List<BannerModel>> _fetchBanners() async {
    try {
      final response = await Supabase.instance.client
          .from('banners')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List).map((e) => BannerModel.fromJson(e)).toList();
    } catch (e) {
      // Return empty list on error instead of throwing to prevent breaking the UI
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchBanners());
  }
}
