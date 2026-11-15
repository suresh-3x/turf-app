import 'dart:async';
import 'dart:convert';

import '../../utils/slot_generator.dart';

typedef DbRow = Map<String, dynamic>;

/// An in-memory stand-in for the Supabase database, used in demo mode.
///
/// Rows are stored as maps in the same shape as the real tables, so the app's
/// models parse them unchanged. The whole thing serialises to JSON so it can be
/// saved on the device between launches.
class MockDatabase {
  MockDatabase._();

  /// Simulated network delay so loading states are visible.
  Duration latency = const Duration(milliseconds: 250);

  /// Called with the serialised database after every change.
  void Function(String json)? onChanged;

  List<DbRow> users = [];
  List<DbRow> services = [];
  List<DbRow> slots = [];
  List<DbRow> bookings = [];
  List<DbRow> reviews = [];
  List<DbRow> notifications = [];
  String? sessionUserId;
  int _nextId = 1;

  final _changes = StreamController<void>.broadcast();
  final _sessionChanges = StreamController<String?>.broadcast();

  /// Fires after every write.
  Stream<void> get changes => _changes.stream;

  /// Fires when someone signs in or out.
  Stream<String?> get sessionChanges => _sessionChanges.stream;

  String newId(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';

  Future<void> delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  void commit() {
    _changes.add(null);
    onChanged?.call(jsonEncode(toJson()));
  }

  void setSession(String? userId) {
    sessionUserId = userId;
    _sessionChanges.add(userId);
    commit();
  }

  /// Replaces everything with fresh demo data and signs out.
  void resetToSeed({DateTime? now}) {
    final fresh = MockDatabase.seeded(now: now);
    users = fresh.users;
    services = fresh.services;
    slots = fresh.slots;
    bookings = fresh.bookings;
    reviews = fresh.reviews;
    notifications = fresh.notifications;
    _nextId = fresh._nextId;
    setSession(null);
  }

  DbRow? userById(String? id) => users.where((u) => u['id'] == id).firstOrNull;
  DbRow? serviceById(String? id) => services.where((s) => s['id'] == id).firstOrNull;
  DbRow? slotById(String? id) => slots.where((s) => s['id'] == id).firstOrNull;
  DbRow? bookingById(String? id) => bookings.where((b) => b['id'] == id).firstOrNull;

  /// A user row without the password, as the API would return it.
  DbRow? publicUser(String? id) {
    final u = userById(id);
    if (u == null) return null;
    return Map.of(u)..remove('password');
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'users': users,
    'services': services,
    'slots': slots,
    'bookings': bookings,
    'reviews': reviews,
    'notifications': notifications,
    'session': sessionUserId,
    'nextId': _nextId,
  };

  /// Restores a saved database, or returns null if [json] is missing or invalid.
  static MockDatabase? fromJsonString(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final d = jsonDecode(json) as Map<String, dynamic>;
      if (d['version'] != 1) return null;
      List<DbRow> rows(String key) =>
          (d[key] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return MockDatabase._()
        ..users = rows('users')
        ..services = rows('services')
        ..slots = rows('slots')
        ..bookings = rows('bookings')
        ..reviews = rows('reviews')
        ..notifications = rows('notifications')
        ..sessionUserId = d['session'] as String?
        .._nextId = (d['nextId'] as int?) ?? 1;
    } catch (_) {
      return null;
    }
  }

  /// An empty database (no demo data).
  factory MockDatabase.empty() => MockDatabase._();

  /// Demo data: two venue owners, two customers, five services, slots for the
  /// next ten days, and a few bookings and reviews in different states.
  factory MockDatabase.seeded({DateTime? now}) {
    final db = MockDatabase._();
    final n = now ?? DateTime.now();
    String iso(DateTime d) => d.toUtc().toIso8601String();
    final created = iso(n.subtract(const Duration(days: 30)));

    db.users = [
      {
        'id': 'u-vendor-1',
        'name': 'Green Field Sports',
        'email': 'vendor@demo.com',
        'password': 'demo123',
        'role': 'vendor',
        'phone': '+91 98450 12345',
      },
      {
        'id': 'u-vendor-2',
        'name': 'Pixel Play Arena',
        'email': 'owner2@demo.com',
        'password': 'demo123',
        'role': 'vendor',
        'phone': '+91 99000 54321',
      },
      {
        'id': 'u-customer-1',
        'name': 'Asha Rao',
        'email': 'customer@demo.com',
        'password': 'demo123',
        'role': 'customer',
        'phone': '+91 90080 11223',
      },
      {
        'id': 'u-customer-2',
        'name': 'Ravi Kumar',
        'email': 'ravi@demo.com',
        'password': 'demo123',
        'role': 'customer',
        'phone': null,
      },
    ];

    DbRow service(
      String id,
      String vendor,
      String name,
      String category,
      String location,
      double price,
      String description,
    ) => {
      'id': id,
      'vendor_id': vendor,
      'name': name,
      'description': description,
      'category': category,
      'location': location,
      'price_per_slot': price,
      'image_url': null,
      'is_active': true,
      'created_at': created,
    };

    db.services = [
      service(
        'svc-turf-5',
        'u-vendor-1',
        'Green Field Turf – 5-a-side',
        'Football turf',
        'Koramangala, Bengaluru',
        1200,
        'FIFA-grade artificial turf with floodlights. Bibs and a ball included. Changing room and drinking water on site.',
      ),
      service(
        'svc-turf-7',
        'u-vendor-1',
        'Green Field Turf – 7-a-side',
        'Football turf',
        'Koramangala, Bengaluru',
        1800,
        'Larger pitch for 7-a-side games. Floodlit until 11pm.',
      ),
      service(
        'svc-badminton',
        'u-vendor-1',
        'Shuttle Hub – Court 1',
        'Badminton',
        'HSR Layout, Bengaluru',
        400,
        'Wooden indoor court with synthetic mat. Racquets available on request.',
      ),
      service(
        'svc-gaming',
        'u-vendor-2',
        'Pixel Play – VR & Consoles',
        'Gaming zone',
        'Indiranagar, Bengaluru',
        300,
        'PS5, Xbox and VR stations for up to 6 players. Snacks counter.',
      ),
      service(
        'svc-cricket',
        'u-vendor-2',
        'Box Cricket Nets',
        'Cricket',
        'Whitefield, Bengaluru',
        900,
        'Enclosed box cricket arena with bowling machine (₹200 extra).',
      ),
    ];

    // Upcoming slots.
    void open(String serviceId, int openHour, int closeHour, int minutes) {
      final ranges = generateSlots(
        SlotPlan(
          firstDay: n,
          numberOfDays: 10,
          openMinutes: openHour * 60,
          closeMinutes: closeHour * 60,
          slotLength: Duration(minutes: minutes),
        ),
        now: n,
      );
      for (final r in ranges) {
        db.slots.add({
          'id': db.newId('slot'),
          'service_id': serviceId,
          'start_time': iso(r.start),
          'end_time': iso(r.end),
          'is_booked': false,
        });
      }
    }

    open('svc-turf-5', 6, 23, 60);
    open('svc-turf-7', 6, 23, 90);
    open('svc-badminton', 6, 22, 60);
    open('svc-gaming', 11, 23, 60);
    open('svc-cricket', 7, 22, 60);

    // Past slots used by finished bookings.
    String pastSlot(String serviceId, int daysAgo, int hour) {
      final d = DateTime(n.year, n.month, n.day - daysAgo, hour);
      final id = db.newId('slot');
      db.slots.add({
        'id': id,
        'service_id': serviceId,
        'start_time': iso(d),
        'end_time': iso(d.add(const Duration(hours: 1))),
        'is_booked': true,
      });
      return id;
    }

    String book(
      String customer,
      String serviceId,
      String slotId,
      String status, {
      String? notes,
      int daysAgo = 1,
    }) {
      final id = db.newId('bk');
      db.bookings.add({
        'id': id,
        'customer_id': customer,
        'service_id': serviceId,
        'slot_id': slotId,
        'booking_time': iso(n.subtract(Duration(days: daysAgo))),
        'status': status,
        'notes': notes,
        'updated_at': iso(n),
      });
      db.slotById(slotId)!['is_booked'] =
          status == 'pending' || status == 'confirmed' || status == 'completed';
      return id;
    }

    /// First free future slot of a service at least [hoursAhead] from now.
    String futureSlot(String serviceId, int hoursAhead) {
      final after = n.add(Duration(hours: hoursAhead));
      final slot = db.slots
          .where(
            (s) =>
                s['service_id'] == serviceId &&
                s['is_booked'] == false &&
                DateTime.parse(s['start_time'] as String).isAfter(after),
          )
          .first;
      return slot['id'] as String;
    }

    void review(
      String bookingId,
      String customer,
      String serviceId,
      String vendor,
      int rating,
      String comment,
      int daysAgo,
    ) {
      db.reviews.add({
        'id': db.newId('rv'),
        'booking_id': bookingId,
        'customer_id': customer,
        'vendor_id': vendor,
        'service_id': serviceId,
        'rating': rating,
        'comment': comment,
        'customer_name': db.userById(customer)!['name'],
        'created_at': iso(n.subtract(Duration(days: daysAgo))),
      });
    }

    // Finished bookings with reviews.
    final r1 = book(
      'u-customer-2',
      'svc-turf-5',
      pastSlot('svc-turf-5', 6, 19),
      'completed',
      daysAgo: 8,
    );
    review(
      r1,
      'u-customer-2',
      'svc-turf-5',
      'u-vendor-1',
      5,
      'Great surface and lights. Will book again!',
      5,
    );
    final r2 = book(
      'u-customer-2',
      'svc-gaming',
      pastSlot('svc-gaming', 4, 17),
      'completed',
      daysAgo: 5,
    );
    review(
      r2,
      'u-customer-2',
      'svc-gaming',
      'u-vendor-2',
      4,
      'Fun VR setup, a bit crowded on weekends.',
      3,
    );
    final r3 = book(
      'u-customer-1',
      'svc-badminton',
      pastSlot('svc-badminton', 9, 7),
      'completed',
      daysAgo: 10,
    );
    review(r3, 'u-customer-1', 'svc-badminton', 'u-vendor-1', 4, 'Good court, friendly staff.', 8);

    // Asha: one to review, one confirmed, one waiting, one cancelled.
    book('u-customer-1', 'svc-turf-5', pastSlot('svc-turf-5', 2, 20), 'completed', daysAgo: 3);
    book(
      'u-customer-1',
      'svc-turf-7',
      futureSlot('svc-turf-7', 26),
      'confirmed',
      notes: '12 players',
    );
    book('u-customer-1', 'svc-gaming', futureSlot('svc-gaming', 50), 'pending');
    book('u-customer-1', 'svc-cricket', pastSlot('svc-cricket', 1, 18), 'cancelled', daysAgo: 4);

    // Green Field Sports: a request to answer and a game to mark completed.
    final pendingForVendor = book(
      'u-customer-2',
      'svc-turf-5',
      futureSlot('svc-turf-5', 20),
      'pending',
      notes: 'Office team, 10 players',
    );
    book(
      'u-customer-2',
      'svc-badminton',
      pastSlot('svc-badminton', 0, n.hour > 0 ? n.hour - 1 : 0),
      'confirmed',
      daysAgo: 1,
    );

    db.notifications = [
      {
        'id': db.newId('nt'),
        'user_id': 'u-vendor-1',
        'title': 'New booking request',
        'body': 'Ravi Kumar requested Green Field Turf – 5-a-side.',
        'booking_id': pendingForVendor,
        'is_read': false,
        'created_at': iso(n.subtract(const Duration(hours: 2))),
      },
      {
        'id': db.newId('nt'),
        'user_id': 'u-customer-1',
        'title': 'Booking confirmed',
        'body': 'Your booking for Green Field Turf – 7-a-side was confirmed.',
        'booking_id': null,
        'is_read': false,
        'created_at': iso(n.subtract(const Duration(hours: 5))),
      },
    ];
    return db;
  }
}
