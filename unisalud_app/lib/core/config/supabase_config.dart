/// Credenciales de tu proyecto Supabase.
///
/// Las encuentras en: Supabase → Project Settings → API Keys / Data API.
/// Puedes pegarlas aquí directamente o pasarlas al compilar:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_KEY=sb_publishable_xxxx
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://TU-PROYECTO.supabase.co',
  );

  /// Usa la "Publishable key" (o la antigua "anon public").
  /// NUNCA pongas aquí la "secret" / "service_role".
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'TU-PUBLISHABLE-KEY',
  );

  static bool get configurado =>
      !url.contains('TU-PROYECTO') && !publishableKey.startsWith('TU-');
}
