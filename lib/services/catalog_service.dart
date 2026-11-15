import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/review.dart';
import '../models/service.dart';
import '../models/slot.dart';
import 'auth_service.dart';
import 'supabase_providers.dart';

/// Services (the things vendors list), their time slots and reviews.
final catalogServiceProvider = Provider<CatalogService>(
  (ref) => CatalogService(ref.watch(supabaseClientProvider)),
);

class ServiceQuery {
  const ServiceQuery({this.category, this.search = ''});
  final String? category;
  final String search;

  @override
  bool operator ==(Object other) =>
      other is ServiceQuery && other.category == category && other.search == search;

  @override
  int get hashCode => Object.hash(category, search);
}

final browseServicesProvider = FutureProvider.autoDispose.family<List<Service>, ServiceQuery>((
  ref,
  query,
) {
  return ref
      .watch(catalogServiceProvider)
      .fetchActiveServices(category: query.category, search: query.search);
});

final serviceDetailProvider = FutureProvider.autoDispose.family<Service, String>((ref, id) {
  return ref.watch(catalogServiceProvider).fetchService(id);
});

/// Future slots of a service, booked or not (booked ones show as taken).
final upcomingSlotsProvider = FutureProvider.autoDispose.family<List<Slot>, String>((ref, id) {
  return ref.watch(catalogServiceProvider).fetchUpcomingSlots(id);
});

final serviceReviewsProvider = FutureProvider.autoDispose.family<List<Review>, String>((ref, id) {
  return ref.watch(catalogServiceProvider).fetchReviews(id);
});

final slotDetailProvider = FutureProvider.autoDispose.family<Slot, String>((ref, id) {
  return ref.watch(catalogServiceProvider).fetchSlot(id);
});

/// Services owned by the signed-in vendor.
final myServicesProvider = FutureProvider.autoDispose<List<Service>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(catalogServiceProvider).fetchVendorServices(userId);
});

class CatalogService {
  CatalogService(this._client);
  final SupabaseClient _client;

  static const _serviceWithVendor = '*, vendor:users(id, name, email, role, phone)';

  Future<List<Service>> fetchActiveServices({String? category, String search = ''}) async {
    var query = _client.from('services').select().eq('is_active', true);
    if (category != null) query = query.eq('category', category);
    final term = search.trim().replaceAll(RegExp(r'[,()%*]'), ' ');
    if (term.isNotEmpty) {
      query = query.or('name.ilike.%$term%,location.ilike.%$term%,description.ilike.%$term%');
    }
    final rows = await query.order('created_at', ascending: false);
    return _withRatings(rows.map(Service.fromJson).toList());
  }

  Future<Service> fetchService(String id) async {
    final row = await _client.from('services').select(_serviceWithVendor).eq('id', id).single();
    final list = await _withRatings([Service.fromJson(row)]);
    return list.first;
  }

  Future<List<Service>> fetchVendorServices(String vendorId) async {
    final rows = await _client
        .from('services')
        .select()
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);
    return _withRatings(rows.map(Service.fromJson).toList());
  }

  Future<Service> createService(Service service) async {
    final row = await _client.from('services').insert(service.toWriteJson()).select().single();
    return Service.fromJson(row);
  }

  Future<void> updateService(Service service) async {
    final data = service.toWriteJson()..remove('vendor_id');
    await _client.from('services').update(data).eq('id', service.id);
  }

  Future<void> setServiceActive(String id, bool active) async {
    await _client.from('services').update({'is_active': active}).eq('id', id);
  }

  Future<void> deleteService(String id) async {
    await _client.from('services').delete().eq('id', id);
  }

  Future<List<Slot>> fetchUpcomingSlots(String serviceId) async {
    final rows = await _client
        .from('slots')
        .select()
        .eq('service_id', serviceId)
        .gt('start_time', DateTime.now().toUtc().toIso8601String())
        .order('start_time');
    return rows.map(Slot.fromJson).toList();
  }

  /// Slots of a service starting within [from]..[to] (local times).
  Future<List<Slot>> fetchSlotsBetween(String serviceId, DateTime from, DateTime to) async {
    final rows = await _client
        .from('slots')
        .select()
        .eq('service_id', serviceId)
        .gte('start_time', from.toUtc().toIso8601String())
        .lt('start_time', to.toUtc().toIso8601String())
        .order('start_time');
    return rows.map(Slot.fromJson).toList();
  }

  Future<Slot> fetchSlot(String id) async {
    final row = await _client.from('slots').select().eq('id', id).single();
    return Slot.fromJson(row);
  }

  Future<void> createSlots(String serviceId, List<SlotRange> ranges) async {
    if (ranges.isEmpty) return;
    await _client.from('slots').insert(ranges.map((r) => r.toInsertJson(serviceId)).toList());
  }

  Future<void> deleteSlot(String id) async {
    await _client.from('slots').delete().eq('id', id);
  }

  Future<List<Review>> fetchReviews(String serviceId) async {
    final rows = await _client
        .from('reviews')
        .select()
        .eq('service_id', serviceId)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(Review.fromJson).toList();
  }

  /// Service, vendor and customer are filled in by a database trigger.
  Future<void> submitReview({
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    await _client.from('reviews').insert({
      'booking_id': bookingId,
      'customer_id': _client.auth.currentUser?.id,
      'rating': rating,
      'comment': comment.trim().isEmpty ? null : comment.trim(),
    });
  }

  Future<List<Service>> _withRatings(List<Service> services) async {
    if (services.isEmpty) return services;
    final rows = await _client
        .from('service_ratings')
        .select()
        .inFilter('service_id', services.map((s) => s.id).toList());
    final byId = {for (final r in rows) r['service_id'] as String: r};
    return services.map((s) {
      final r = byId[s.id];
      if (r == null) return s;
      return s.copyWith(
        averageRating: (r['average_rating'] as num?)?.toDouble(),
        reviewCount: (r['review_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }
}
