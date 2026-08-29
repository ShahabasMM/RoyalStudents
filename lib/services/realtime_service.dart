import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  static SupabaseClient get client =>
      Supabase.instance.client;

  static RealtimeChannel libraryChannel({
    required void Function() onChanged,
  }) {
    final channel = client.channel(
      'student-library-realtime',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'library_books',
          callback: (_) {
            onChanged();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'library_reservations',
          callback: (_) {
            onChanged();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'library_staff_loans',
          callback: (_) {
            onChanged();
          },
        )
        .subscribe();

    return channel;
  }

  static Future<void> remove(
    RealtimeChannel channel,
  ) async {
    await client.removeChannel(channel);
  }
}