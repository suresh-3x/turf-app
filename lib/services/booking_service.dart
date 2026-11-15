import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking.dart';
import 'auth_service.dart';
import 'supabase_providers.dart';

final bookingServiceProvider = Provider<BookingService>(
  (ref) => BookingService(ref.watch(supabaseClientProvider)),
);

/// Bookings made by the signed-in customer, soonest first.
final myBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(bookingServiceProvider).fetchCustomerBookings(userId);
});

/// Bookings for the signed-in vendor's services, soonest first.
final vendorBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(bookingServiceProvider).fetchVendorBookings(userId);
});

final bookingDetailProvider = FutureProvider.autoDispose.family<Booking, String>((ref, id) {
  return ref.watch(bookingServiceProvider).fetchBooking(id);
});

class BookingService {
  BookingService(this._client);
  final SupabaseClient _client;

  static const _select =
      '*, service:services!inner(*), slot:slots(*), customer:users(id, name, email, role, phone), reviews(id)';

  /// Books a slot atomically. Fails with a readable message if it was taken.
  Future<String> bookSlot(String slotId, {String? notes}) async {
    final result = await _client.rpc('book_slot', params: {'p_slot_id': slotId, 'p_notes': notes});
    return (result as Map<String, dynamic>)['id'] as String;
  }

  Future<void> updateStatus(String bookingId, BookingStatus status) async {
    await _client.rpc(
      'update_booking_status',
      params: {'p_booking_id': bookingId, 'p_status': status.name},
    );
  }

  Future<void> cancel(String bookingId) => updateStatus(bookingId, BookingStatus.cancelled);

  Future<List<Booking>> fetchCustomerBookings(String customerId) async {
    final rows = await _client.from('bookings').select(_select).eq('customer_id', customerId);
    return _sorted(rows.map(Booking.fromJson).toList());
  }

  Future<List<Booking>> fetchVendorBookings(String vendorId) async {
    final rows = await _client.from('bookings').select(_select).eq('service.vendor_id', vendorId);
    return _sorted(rows.map(Booking.fromJson).toList());
  }

  Future<Booking> fetchBooking(String id) async {
    final row = await _client.from('bookings').select(_select).eq('id', id).single();
    return Booking.fromJson(row);
  }

  static List<Booking> _sorted(List<Booking> list) {
    final far = DateTime(9999);
    return list..sort((a, b) => (a.startTime ?? far).compareTo(b.startTime ?? far));
  }
}
