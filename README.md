# TurfApp

A Flutter app for booking local sports and leisure venues: football turfs, cricket nets,
badminton courts, gaming zones and the like.

There are two kinds of account:

- **Customers** browse venues, pick a free time slot, request a booking, follow its status,
  cancel it, and leave a review afterwards.
- **Business owners (vendors)** list their services, open time slots (one at a time or a
  week's worth in one go), accept or decline requests, mark bookings completed, and see their
  booking history and monthly earnings.

Both get in-app notifications when a booking changes. There's no payment in the MVP; customers
pay at the venue.

## Tech

| Part | Choice |
| --- | --- |
| App | Flutter (Android, iOS, web, desktop) |
| State | Riverpod 2 |
| Navigation | go_router (role-aware redirects) |
| Backend | Supabase: Auth, Postgres with row-level security, Realtime |

## Getting started

### 1. Set up the database

The schema lives in `supabase/migrations/`. Apply it to your Supabase project with the
[Supabase CLI](https://supabase.com/docs/guides/cli):

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

…or paste each migration file, in order, into the SQL editor in the Supabase dashboard.

> The `20261115000000_mvp_booking_platform.sql` migration links `public.users` to
> `auth.users` and removes any profile rows that don't belong to a real auth user. It's meant
> for a project that has no real users yet.

### 2. Configure Supabase Auth

In the dashboard, under **Authentication → Providers → Email**:

- **Confirm email ON** (recommended): after signing up, users get an email and must click the
  link before logging in. The app shows a "check your email" screen.
- **Confirm email OFF**: users are logged straight in after signing up. Handy while testing.

### 3. Run the app

```bash
flutter pub get
flutter run
```

The Supabase URL and anon key default to the values in `lib/utils/constants.dart`. To point
at a different project without editing code:

```bash
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=...
```

The anon key is meant to be public; the row-level security policies decide what each user can
read and write.

### 4. Try it

1. Sign up as a business owner ("List my venue"), add a service, and open some slots.
2. In another browser or device, sign up as a customer, find the venue and book a slot.
3. As the owner, accept the request from **Bookings**. The customer sees a notification.
4. Once the slot time has passed, mark the booking completed. The customer can then leave a
   review.

## How bookings stay consistent

Everything that has to be atomic or trusted happens in the database, not the app:

- `book_slot(slot_id, notes)` locks the slot row, checks that it's free and in the future,
  creates the booking and marks the slot booked, all in one transaction. When two people tap
  "book" at the same moment, exactly one of them gets the slot. A unique index backs this up.
- `update_booking_status(booking_id, status)` enforces who may change what:
  - customers can cancel before the slot starts
  - vendors can accept or decline pending requests, and cancel or complete confirmed bookings
  - cancelling or declining frees the slot again
- Clients can't insert or update bookings directly. Row-level security only allows reads.
- A vendor's slots for one service can't overlap (an exclusion constraint), and booked slots
  can't be edited or deleted.
- Profiles are created by a trigger on sign-up, and users can't change their own role.
- Notifications are written by a trigger whenever a booking is created or changes status.

## Project layout

```
lib/
  main.dart, app.dart     startup and theme
  router.dart             routes and role-based redirects
  models/                 plain data classes with fromJson
  services/               Supabase access + Riverpod providers
    auth_service.dart       sign-in/up, current user & profile
    catalog_service.dart    services, slots, reviews
    booking_service.dart    booking functions and queries
    notification_service.dart  realtime in-app notifications
  screens/
    auth/                 onboarding, login, signup
    customer/             explore, service detail, book, my bookings, review
    vendor/               dashboard, requests, history, services, slots
    shared/               splash, profile, notifications
  widgets/                cards, slot calendar, rating, status chip…
  utils/                  formatting, validation, slot generator
supabase/migrations/      database schema, policies and functions
test/                     unit and widget tests
```

## Tests

```bash
flutter test
```

The tests cover the slot generator, the routing rules, the dashboard numbers and JSON parsing,
plus widget tests that run the whole app with fake backends: login validation, browsing and
filtering, booking a slot end to end, notifications, and a vendor accepting a request.

## Not in the MVP yet

- **Push notifications.** Notifications are in-app and realtime today. For push, add Firebase
  Cloud Messaging (it needs `google-services.json` / `GoogleService-Info.plist` from your
  Firebase project) and send from a Supabase Edge Function or database webhook on the
  `notifications` table.
- **Maps and location search.** Location is free text for now.
- **Photo upload.** Vendors paste an image URL; Supabase Storage is the natural next step.
- **Online payments** (Razorpay or Stripe) and an admin dashboard, as planned for V2.
