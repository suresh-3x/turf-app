import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;

import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/review.dart';
import '../../models/service.dart';
import '../../models/slot.dart';
import '../../utils/formatters.dart';
import '../auth_service.dart';
import '../booking_service.dart';
import '../catalog_service.dart';
import '../notification_service.dart';
import 'mock_database.dart';

// These classes follow the same rules as the SQL migration (row-level
// security, book_slot, update_booking_status, triggers), so the app behaves
// the same in demo mode. Errors use Supabase's exception types so the app's
// error handling is unchanged.

/// The demo database, or null when the app talks to Supabase.
final mockDatabaseProvider = Provider<MockDatabase?>((ref) => null);

/// Provider overrides that switch the whole app to [db].
List<Override> mockBackendOverrides(MockDatabase db) => [
  mockDatabaseProvider.overrideWithValue(db),
  authServiceProvider.overrideWithValue(MockAuthService(db)),
  catalogServiceProvider.overrideWithValue(MockCatalogService(db)),
  bookingServiceProvider.overrideWithValue(MockBookingService(db)),
  notificationServiceProvider.overrideWithValue(MockNotificationService(db)),
];

PostgrestException _denied() =>
    const PostgrestException(message: 'permission denied', code: '42501');
PostgrestException _raise(String message) => PostgrestException(message: message, code: 'P0001');
PostgrestException _notFound() => const PostgrestException(message: 'Not found', code: 'PGRST116');

String _iso(DateTime d) => d.toUtc().toIso8601String();
DateTime _time(DbRow r, String key) => DateTime.parse(r[key] as String).toLocal();

// -----------------------------------------------------------------------------

class MockAuthService implements AuthService {
  MockAuthService(this.db);
  final MockDatabase db;

  @override
  String? get currentUserId => db.sessionUserId;

  @override
  Stream<String?> get userIdChanges => db.sessionChanges;

  @override
  Future<void> signIn(String email, String password) async {
    await db.delay();
    final user = db.users
        .where((u) => (u['email'] as String).toLowerCase() == email.trim().toLowerCase())
        .firstOrNull;
    if (user == null || user['password'] != password) {
      throw const AuthException('Invalid login credentials');
    }
    db.setSession(user['id'] as String);
  }

  @override
  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
  }) async {
    await db.delay();
    final e = email.trim().toLowerCase();
    if (db.users.any((u) => (u['email'] as String).toLowerCase() == e)) {
      throw const AuthException('User already registered');
    }
    if (password.length < 6) {
      throw const AuthException('Password should be at least 6 characters.');
    }
    final id = db.newId('u');
    db.users.add({
      'id': id,
      'name': name.trim().isEmpty ? e.split('@').first : name.trim(),
      'email': e,
      'password': password,
      'role': role.name,
      'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
    });
    // Demo mode has no email confirmation: sign straight in.
    db.setSession(id);
    return const SignUpResult(needsEmailConfirmation: false);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await db.delay();
    throw const AuthException(
      'Password reset emails are not sent in demo mode. Demo password: demo123',
    );
  }

  @override
  Future<void> signOut() async => db.setSession(null);

  @override
  Future<AppUser?> fetchProfile(String userId) async {
    await db.delay();
    final u = db.publicUser(userId);
    return u == null ? null : AppUser.fromJson(u);
  }

  @override
  Future<void> updateProfile({required String name, String? phone}) async {
    await db.delay();
    final u = db.userById(db.sessionUserId);
    if (u == null) throw const AuthException('You are not signed in.');
    u['name'] = name.trim();
    u['phone'] = (phone == null || phone.trim().isEmpty) ? null : phone.trim();
    db.commit();
  }
}

// -----------------------------------------------------------------------------

class MockCatalogService implements CatalogService {
  MockCatalogService(this.db);
  final MockDatabase db;

  String get _me {
    final id = db.sessionUserId;
    if (id == null) throw _denied();
    return id;
  }

  bool get _iAmVendor => db.userById(db.sessionUserId)?['role'] == 'vendor';

  DbRow _ownService(String serviceId) {
    final s = db.serviceById(serviceId);
    if (s == null || s['vendor_id'] != _me) throw _denied();
    return s;
  }

  Service _toService(DbRow row, {bool withVendor = false}) {
    final data = Map<String, dynamic>.of(row);
    if (withVendor) data['vendor'] = db.publicUser(row['vendor_id'] as String);
    final ratings = db.reviews.where((r) => r['service_id'] == row['id']).toList();
    final service = Service.fromJson(data);
    if (ratings.isEmpty) return service;
    final avg = ratings.fold<int>(0, (sum, r) => sum + (r['rating'] as int)) / ratings.length;
    return service.copyWith(averageRating: (avg * 10).round() / 10, reviewCount: ratings.length);
  }

  List<DbRow> _newestFirst(Iterable<DbRow> rows) =>
      rows.toList()
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));

  @override
  Future<List<Service>> fetchActiveServices({String? category, String search = ''}) async {
    await db.delay();
    final q = search.trim().toLowerCase();
    final rows = db.services.where(
      (s) =>
          s['is_active'] == true &&
          (category == null || s['category'] == category) &&
          (q.isEmpty ||
              [
                'name',
                'location',
                'description',
              ].any((k) => ((s[k] as String?) ?? '').toLowerCase().contains(q))),
    );
    return _newestFirst(rows).map(_toService).toList();
  }

  @override
  Future<Service> fetchService(String id) async {
    await db.delay();
    final row = db.serviceById(id);
    if (row == null) throw _notFound();
    return _toService(row, withVendor: true);
  }

  @override
  Future<List<Service>> fetchVendorServices(String vendorId) async {
    await db.delay();
    return _newestFirst(
      db.services.where((s) => s['vendor_id'] == vendorId),
    ).map(_toService).toList();
  }

  @override
  Future<Service> createService(Service service) async {
    await db.delay();
    if (!_iAmVendor || service.vendorId != _me) throw _denied();
    final row = {
      ...service.toWriteJson(),
      'id': db.newId('svc'),
      'created_at': _iso(DateTime.now()),
    };
    db.services.add(row);
    db.commit();
    return _toService(row);
  }

  @override
  Future<void> updateService(Service service) async {
    await db.delay();
    final row = _ownService(service.id);
    row.addAll(service.toWriteJson()..remove('vendor_id'));
    db.commit();
  }

  @override
  Future<void> setServiceActive(String id, bool active) async {
    await db.delay();
    _ownService(id)['is_active'] = active;
    db.commit();
  }

  @override
  Future<void> deleteService(String id) async {
    await db.delay();
    _ownService(id);
    final bookingIds = db.bookings.where((b) => b['service_id'] == id).map((b) => b['id']).toSet();
    db.notifications.removeWhere((n) => bookingIds.contains(n['booking_id']));
    db.reviews.removeWhere((r) => r['service_id'] == id || bookingIds.contains(r['booking_id']));
    db.bookings.removeWhere((b) => b['service_id'] == id);
    db.slots.removeWhere((s) => s['service_id'] == id);
    db.services.removeWhere((s) => s['id'] == id);
    db.commit();
  }

  List<Slot> _slots(bool Function(DbRow) test) {
    final list = db.slots.where(test).map(Slot.fromJson).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }

  @override
  Future<List<Slot>> fetchUpcomingSlots(String serviceId) async {
    await db.delay();
    final now = DateTime.now();
    return _slots((s) => s['service_id'] == serviceId && _time(s, 'start_time').isAfter(now));
  }

  @override
  Future<List<Slot>> fetchSlotsBetween(String serviceId, DateTime from, DateTime to) async {
    await db.delay();
    return _slots((s) {
      if (s['service_id'] != serviceId) return false;
      final start = _time(s, 'start_time');
      return !start.isBefore(from) && start.isBefore(to);
    });
  }

  @override
  Future<Slot> fetchSlot(String id) async {
    await db.delay();
    final row = db.slotById(id);
    if (row == null) throw _notFound();
    return Slot.fromJson(row);
  }

  @override
  Future<void> createSlots(String serviceId, List<SlotRange> ranges) async {
    await db.delay();
    _ownService(serviceId);
    final existing = db.slots
        .where((s) => s['service_id'] == serviceId)
        .map((s) => SlotRange(_time(s, 'start_time'), _time(s, 'end_time')))
        .toList();
    final accepted = <SlotRange>[];
    for (final r in ranges) {
      if (!r.end.isAfter(r.start)) {
        throw const PostgrestException(message: 'end before start', code: '23514');
      }
      final clash = [
        ...existing,
        ...accepted,
      ].any((e) => r.start.isBefore(e.end) && r.end.isAfter(e.start));
      if (clash) throw const PostgrestException(message: 'overlap', code: '23P01');
      accepted.add(r);
    }
    for (final r in accepted) {
      db.slots.add({...r.toInsertJson(serviceId), 'id': db.newId('slot'), 'is_booked': false});
    }
    db.commit();
  }

  @override
  Future<void> deleteSlot(String id) async {
    await db.delay();
    final slot = db.slotById(id);
    if (slot == null) return;
    _ownService(slot['service_id'] as String);
    // Like the RLS policy: booked slots are silently left alone.
    if (slot['is_booked'] == true) return;
    db.slots.remove(slot);
    db.commit();
  }

  @override
  Future<List<Review>> fetchReviews(String serviceId) async {
    await db.delay();
    final rows = db.reviews.where((r) => r['service_id'] == serviceId).toList()
      ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    return rows.take(50).map(Review.fromJson).toList();
  }

  @override
  Future<void> submitReview({
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    await db.delay();
    final booking = db.bookingById(bookingId);
    if (booking == null || booking['customer_id'] != _me || booking['status'] != 'completed') {
      throw _denied();
    }
    if (rating < 1 || rating > 5) {
      throw const PostgrestException(message: 'rating out of range', code: '23514');
    }
    if (db.reviews.any((r) => r['booking_id'] == bookingId)) {
      throw const PostgrestException(message: 'duplicate', code: '23505');
    }
    final service = db.serviceById(booking['service_id'] as String)!;
    db.reviews.add({
      'id': db.newId('rv'),
      'booking_id': bookingId,
      'customer_id': _me,
      'vendor_id': service['vendor_id'],
      'service_id': service['id'],
      'rating': rating,
      'comment': comment.trim().isEmpty ? null : comment.trim(),
      'customer_name': db.userById(_me)?['name'],
      'created_at': _iso(DateTime.now()),
    });
    db.commit();
  }
}

// -----------------------------------------------------------------------------

class MockBookingService implements BookingService {
  MockBookingService(this.db);
  final MockDatabase db;

  /// The booking with its service, slot, customer and reviews embedded, like
  /// the Supabase select.
  Booking _expand(DbRow b) => Booking.fromJson({
    ...b,
    'service': db.serviceById(b['service_id'] as String),
    'slot': db.slotById(b['slot_id'] as String),
    'customer': db.publicUser(b['customer_id'] as String),
    'reviews': db.reviews
        .where((r) => r['booking_id'] == b['id'])
        .map((r) => {'id': r['id']})
        .toList(),
  });

  bool _canSee(DbRow b) {
    final me = db.sessionUserId;
    return b['customer_id'] == me || db.serviceById(b['service_id'] as String)?['vendor_id'] == me;
  }

  void _notify(String? userId, String title, String body, String bookingId) {
    if (userId == null) return;
    db.notifications.add({
      'id': db.newId('nt'),
      'user_id': userId,
      'title': title,
      'body': body,
      'booking_id': bookingId,
      'is_read': false,
      'created_at': _iso(DateTime.now()),
    });
  }

  String _when(DbRow slot) => formatSlot(_time(slot, 'start_time'), _time(slot, 'end_time'));

  @override
  Future<String> bookSlot(String slotId, {String? notes}) async {
    await db.delay();
    final me = db.sessionUserId;
    if (me == null) throw _raise('You must be signed in to book.');
    if (db.userById(me)?['role'] != 'customer')
      throw _raise('Only customer accounts can make bookings.');
    final slot = db.slotById(slotId);
    if (slot == null) throw _raise('This slot no longer exists.');
    if (slot['is_booked'] == true)
      throw _raise('Sorry, this slot has just been booked by someone else.');
    if (!_time(slot, 'start_time').isAfter(DateTime.now()))
      throw _raise('This slot has already started.');
    final service = db.serviceById(slot['service_id'] as String)!;
    if (service['is_active'] != true)
      throw _raise('This service is not taking bookings right now.');

    final id = db.newId('bk');
    final trimmed = notes?.trim();
    db.bookings.add({
      'id': id,
      'customer_id': me,
      'service_id': service['id'],
      'slot_id': slotId,
      'booking_time': _iso(DateTime.now()),
      'status': 'pending',
      'notes': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      'updated_at': _iso(DateTime.now()),
    });
    slot['is_booked'] = true;
    _notify(
      service['vendor_id'] as String,
      'New booking request',
      '${db.userById(me)?['name'] ?? 'A customer'} requested ${service['name']} on ${_when(slot)}',
      id,
    );
    db.commit();
    return id;
  }

  @override
  Future<void> updateStatus(String bookingId, BookingStatus status) async {
    await db.delay();
    final b = db.bookingById(bookingId);
    if (b == null || !_canSee(b)) throw _raise('Booking not found.');
    final me = db.sessionUserId;
    final service = db.serviceById(b['service_id'] as String)!;
    final slot = db.slotById(b['slot_id'] as String)!;
    final current = BookingStatus.fromString(b['status'] as String);
    final isCustomer = b['customer_id'] == me;
    final isVendor = service['vendor_id'] == me;

    if (isCustomer && status == BookingStatus.cancelled && current.isActive) {
      if (!_time(slot, 'start_time').isAfter(DateTime.now())) {
        throw _raise('This booking has already started and can no longer be cancelled.');
      }
    } else if (isVendor &&
        ((current == BookingStatus.pending &&
                (status == BookingStatus.confirmed || status == BookingStatus.rejected)) ||
            (current == BookingStatus.confirmed &&
                (status == BookingStatus.completed || status == BookingStatus.cancelled)))) {
      // allowed
    } else {
      throw _raise('You cannot change this booking from ${current.name} to ${status.name}.');
    }

    b['status'] = status.name;
    b['updated_at'] = _iso(DateTime.now());
    if (status == BookingStatus.cancelled || status == BookingStatus.rejected) {
      slot['is_booked'] = false;
    }

    final what = '${service['name']} on ${_when(slot)}';
    switch (status) {
      case BookingStatus.confirmed || BookingStatus.rejected || BookingStatus.completed:
        _notify(
          b['customer_id'] as String,
          'Booking ${status.name}',
          'Your booking for $what was ${status.name}.',
          bookingId,
        );
      case BookingStatus.cancelled:
        _notify(
          isCustomer ? service['vendor_id'] as String : b['customer_id'] as String,
          'Booking cancelled',
          'The booking for $what was cancelled.',
          bookingId,
        );
      case BookingStatus.pending:
        break;
    }
    db.commit();
  }

  @override
  Future<void> cancel(String bookingId) => updateStatus(bookingId, BookingStatus.cancelled);

  List<Booking> _sorted(Iterable<DbRow> rows) {
    final far = DateTime(9999);
    return rows.map(_expand).toList()
      ..sort((a, b) => (a.startTime ?? far).compareTo(b.startTime ?? far));
  }

  @override
  Future<List<Booking>> fetchCustomerBookings(String customerId) async {
    await db.delay();
    if (customerId != db.sessionUserId) return [];
    return _sorted(db.bookings.where((b) => b['customer_id'] == customerId));
  }

  @override
  Future<List<Booking>> fetchVendorBookings(String vendorId) async {
    await db.delay();
    if (vendorId != db.sessionUserId) return [];
    return _sorted(
      db.bookings.where((b) => db.serviceById(b['service_id'] as String)?['vendor_id'] == vendorId),
    );
  }

  @override
  Future<Booking> fetchBooking(String id) async {
    await db.delay();
    final b = db.bookingById(id);
    if (b == null || !_canSee(b)) throw _notFound();
    return _expand(b);
  }
}

// -----------------------------------------------------------------------------

class MockNotificationService implements NotificationService {
  MockNotificationService(this.db);
  final MockDatabase db;

  List<AppNotification> _list(String userId) {
    final rows = db.notifications.where((n) => n['user_id'] == userId).toList()
      ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    return rows.take(50).map(AppNotification.fromJson).toList();
  }

  @override
  Stream<List<AppNotification>> watch(String userId) async* {
    yield _list(userId);
    await for (final _ in db.changes) {
      yield _list(userId);
    }
  }

  @override
  Future<void> markRead(String id) async {
    final n = db.notifications.where((n) => n['id'] == id).firstOrNull;
    if (n == null || n['user_id'] != db.sessionUserId) return;
    n['is_read'] = true;
    db.commit();
  }

  @override
  Future<void> markAllRead(String userId) async {
    if (userId != db.sessionUserId) return;
    for (final n in db.notifications.where((n) => n['user_id'] == userId)) {
      n['is_read'] = true;
    }
    db.commit();
  }
}
