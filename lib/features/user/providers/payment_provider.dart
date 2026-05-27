import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lastbite/core/services/cloudinary_service.dart';
import 'package:lastbite/core/services/supabase_service.dart';
import 'package:lastbite/features/user/providers/user_orders_provider.dart';

class PaymentState {
  final bool isLoading;
  final File? selectedImage;

  PaymentState({this.isLoading = false, this.selectedImage});

  PaymentState copyWith({bool? isLoading, File? selectedImage}) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      selectedImage: selectedImage ?? this.selectedImage,
    );
  }
}

class PaymentNotifier extends Notifier<PaymentState> {
  final _supabase = SupabaseService().client;
  final ImagePicker _picker = ImagePicker();

  @override
  PaymentState build() {
    return PaymentState();
  }

  void setImage(File file) {
    state = state.copyWith(selectedImage: file);
  }

  void removeImage() {
    state = PaymentState(isLoading: state.isLoading, selectedImage: null);
  }

  Future<bool> uploadPaymentProof(String orderId) async {
    if (state.selectedImage == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      final imageUrl = await CloudinaryService.uploadImage(
        state.selectedImage!,
        folder: 'payments',
      );

      await _supabase
          .from('payments')
          .update({
            'payment_proof': imageUrl,
            'status': 'pending',
          })
          .eq('order_id', orderId);

      await _supabase
          .from('orders')
          .update({
            'status': 'paid', 
            'payment_status': 'waiting_verification',
          })
          .eq('id', orderId);

      state = state.copyWith(isLoading: false);
      
      // Refresh daftar pesanan agar status terbaru muncul
      ref.read(userOrdersProvider.notifier).refresh();
      
      return true;
    } catch (e) {
      print('Error uploading payment proof: $e');
      state = state.copyWith(isLoading: false);
      throw Exception(e.toString());
    }
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', orderId)
          .eq('status', 'pending_payment');
          
      await ref.read(userOrdersProvider.notifier).refresh();
    } catch (e) {
      print('Error cancelling order: $e');
    }
  }
}

final paymentProvider = NotifierProvider<PaymentNotifier, PaymentState>(() {
  return PaymentNotifier();
});
