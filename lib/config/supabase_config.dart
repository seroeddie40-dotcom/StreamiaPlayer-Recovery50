/// Public client configuration for the Streamia Player Supabase project.
///
/// The publishable key is intended for client applications. It is NOT a secret.
/// Database security must be enforced with Row Level Security (RLS).
/// Never place a Supabase secret/service_role key in this file or in the app.
class SupabaseConfig {
  static const String url =
      String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://zhwjlppqdulqtqxaakwl.supabase.co',
      );

  static const String publishableKey =
      String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: 'sb_publishable__MPTuePckIfiB6xz7bKsog_aPbAJwFj',
      );

  static bool get isConfigured =>
      url.startsWith('https://') && publishableKey.startsWith('sb_publishable_');
}
