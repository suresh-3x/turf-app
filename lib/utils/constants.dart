// Supabase project settings. Override at build time with
//   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
// The anon key is public by design; access is controlled by row-level security.
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://kgwzfaazeoodpgpqzxwn.supabase.co',
);
const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtnd3pmYWF6ZW9vZHBncHF6eHduIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMxOTcxMDUsImV4cCI6MjA2ODc3MzEwNX0.aO8iziIYHvz-gaxk04Z_F5bkt4LWsDkIlKYKGT0LqaI',
);

const String appName = 'TurfApp';

/// Which backend the app talks to:
///   mock     – built-in demo database saved on the device (default)
///   supabase – the Supabase project above
/// Choose with --dart-define=BACKEND=supabase
const String backend = String.fromEnvironment('BACKEND', defaultValue: 'mock');
const bool useMockBackend = backend != 'supabase';

/// Categories a vendor can list a service under.
const List<String> serviceCategories = [
  'Football turf',
  'Cricket',
  'Badminton',
  'Tennis',
  'Gaming zone',
  'Swimming',
  'Other',
];
