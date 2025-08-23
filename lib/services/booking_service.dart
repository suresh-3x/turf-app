import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;

import '../models/booking.dart';
import '../models/slot.dart';

final bookingServiceProvider = Provider((ref) => BookingService());

final slotProvider = FutureProvider.family<Slot, String>((ref, slotId) async {
  return ref.watch(bookingServiceProvider).getSlotById(slotId);
});

final userBookingsProvider = FutureProvider.family<List<Booking>, String>((ref, userId) async {
  return ref.watch(bookingServiceProvider).getUserBookings(userId);
});

class BookingService {
  final _supabase = Supabase.instance.client;

  // Fetch bookings for a user
  Future<List<Booking>> getUserBookings(String userId) async {
    final response = await _supabase.from('bookings').select().eq('user_id', userId).order('start_time');
    return (response as List)
        .map((json) => Booking(
              id: json['id'].toString(),
              serviceId: json['service_id'].toString(),
              userId: json['user_id'].toString(),
              startTime: DateTime.parse(json['start_time']),
              endTime: DateTime.parse(json['end_time']),
              status: json['status'] ?? 'pending',
            ))
        .toList();
  }

  // Create a new booking
  Future<void> createBooking({
    required String serviceId,
    required String userId,
    required String slotId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    await _supabase.from('bookings').insert({
      'service_id': serviceId,
      'user_id': userId,
      'slot_id': slotId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'status': 'pending',
    });
    // Mark slot as booked
    await _supabase.from('slots').update({'is_booked': true}).eq('id', slotId);
  }

  // Fetch a slot by ID
  Future<Slot> getSlotById(String slotId) async {
    final response = await _supabase.from('slots').select().eq('id', slotId).single();
    return Slot(
      id: response['id'].toString(),
      serviceId: response['service_id'].toString(),
      startTime: DateTime.parse(response['start_time']),
      endTime: DateTime.parse(response['end_time']),
      isBooked: response['is_booked'] ?? false,
    );
  }

  // Cancel a booking
  Future<void> cancelBooking(String bookingId) async {
    // ...
  }
} 