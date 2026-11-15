import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:turfapp/models/app_notification.dart';
import 'package:turfapp/models/app_user.dart';
import 'package:turfapp/models/booking.dart';
import 'package:turfapp/models/review.dart';
import 'package:turfapp/models/service.dart';
import 'package:turfapp/models/slot.dart';
import 'package:turfapp/services/auth_service.dart';
import 'package:turfapp/services/booking_service.dart';
import 'package:turfapp/services/catalog_service.dart';
import 'package:turfapp/services/notification_service.dart';

const customer = AppUser(id: 'c1', name: 'Asha Rao', email: 'asha@x.com', role: UserRole.customer);
const vendor = AppUser(id: 'v1', name: 'Green Turf', email: 'v@x.com', role: UserRole.vendor);

final tomorrow = DateTime.now().add(const Duration(days: 1));
DateTime at(int hour) => DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour);

final courtA = Service(
  id: 's1',
  vendorId: 'v1',
  name: 'Court A',
  description: '5-a-side astro turf',
  category: 'Football turf',
  location: 'Koramangala',
  pricePerSlot: 1200,
  averageRating: 4.5,
  reviewCount: 2,
  vendor: vendor,
);
final arena = Service(
  id: 's2',
  vendorId: 'v1',
  name: 'Pixel Arena',
  description: 'Consoles and VR',
  category: 'Gaming zone',
  location: 'Indiranagar',
  pricePerSlot: 300,
);

final slots = [
  Slot(id: 'sl1', serviceId: 's1', startTime: at(18), endTime: at(19), isBooked: true),
  Slot(id: 'sl2', serviceId: 's1', startTime: at(19), endTime: at(20), isBooked: false),
];

class FakeAuthService implements AuthService {
  final signIns = <String>[];
  String? failWith;

  @override
  String? get currentUserId => null;

  @override
  Stream<String?> get userIdChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {
    signIns.add(email);
    if (failWith != null) throw AuthException(failWith!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCatalogService implements CatalogService {
  List<Service> services = [courtA, arena];

  @override
  Future<List<Service>> fetchActiveServices({String? category, String search = ''}) async {
    final q = search.toLowerCase();
    return services
        .where((s) => category == null || s.category == category)
        .where(
          (s) =>
              q.isEmpty || s.name.toLowerCase().contains(q) || s.location.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Future<Service> fetchService(String id) async => services.firstWhere((s) => s.id == id);

  @override
  Future<List<Slot>> fetchUpcomingSlots(String serviceId) async =>
      slots.where((s) => s.serviceId == serviceId).toList();

  @override
  Future<Slot> fetchSlot(String id) async => slots.firstWhere((s) => s.id == id);

  @override
  Future<List<Review>> fetchReviews(String serviceId) async => [
    Review(
      id: 'r1',
      bookingId: 'b0',
      rating: 5,
      comment: 'Great surface',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      customerName: 'Ravi',
    ),
  ];

  @override
  Future<List<Service>> fetchVendorServices(String vendorId) async => services;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBookingService implements BookingService {
  final booked = <String>[];
  final statusChanges = <String>[];
  List<Booking> vendorBookings = [];

  @override
  Future<String> bookSlot(String slotId, {String? notes}) async {
    booked.add(slotId);
    return 'new-booking';
  }

  @override
  Future<List<Booking>> fetchCustomerBookings(String customerId) async => [
    for (final id in booked)
      Booking(
        id: 'b-$id',
        customerId: customerId,
        serviceId: 's1',
        slotId: id,
        status: BookingStatus.pending,
        createdAt: DateTime.now(),
        service: courtA,
        slot: slots.firstWhere((s) => s.id == id),
      ),
  ];

  @override
  Future<List<Booking>> fetchVendorBookings(String vendorId) async => vendorBookings;

  @override
  Future<void> updateStatus(String bookingId, BookingStatus status) async {
    statusChanges.add('$bookingId:${status.name}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNotificationService implements NotificationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Provider overrides that sign in [user] (or nobody) with fake backends.
List<Override> fakeOverrides({
  AppUser? user,
  FakeAuthService? auth,
  FakeCatalogService? catalog,
  FakeBookingService? bookings,
  List<AppNotification> notifications = const [],
}) => [
  authServiceProvider.overrideWithValue(auth ?? FakeAuthService()),
  catalogServiceProvider.overrideWithValue(catalog ?? FakeCatalogService()),
  bookingServiceProvider.overrideWithValue(bookings ?? FakeBookingService()),
  notificationServiceProvider.overrideWithValue(FakeNotificationService()),
  currentUserIdProvider.overrideWithValue(user?.id),
  currentProfileProvider.overrideWith((ref) async => user),
  notificationsProvider.overrideWith((ref) => Stream.value(notifications)),
];
