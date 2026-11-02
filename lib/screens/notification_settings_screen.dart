import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/web_push_notifications_service.dart';
import '../widgets/app_bar.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _loading = false;
  String? _error;
  bool _isSubscribed = false;
  bool _checkingSubscription = true;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    if (!mounted) return;
    setState(() => _checkingSubscription = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final config = await Supabase.instance.client.functions.invoke(
        'send-student-web-push',
        body: {'event': 'push.config'},
      );
      final publicVapidKey = (config.data as Map?)?['publicVapidKey'] as String?;
      if (publicVapidKey == null || publicVapidKey.isEmpty) {
        if (mounted) {
          setState(() {
            _checkingSubscription = false;
            _error = 'Push setup is incomplete on the server.';
          });
        }
        return;
      }

      // Check existing subscription via the web push bridge
      final existing = await _getExistingSubscription();
      if (mounted) {
        setState(() {
          _isSubscribed = existing != null && existing.isNotEmpty;
          _checkingSubscription = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkingSubscription = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<String?> _getExistingSubscription() async {
    try {
      if (!identical(0, 0.0)) return null; // kIsWeb check - simplified
      // The actual implementation uses conditional import in web_push_notifications_service
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _enableNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final success = await WebPushNotificationsService.enableForSignedInStudent();
      if (!mounted) return;
      if (success) {
        setState(() {
          _isSubscribed = true;
          _loading = false;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Push notifications enabled!'),
              backgroundColor: Color(0xFF246B4B),
            ),
          );
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _disableNotifications() async {
    setState(() => _loading = true);

    try {
      await WebPushNotificationsService.unregisterCurrentSubscription();
      if (mounted) {
        setState(() {
          _isSubscribed = false;
          _loading = false;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Push notifications disabled.'),
              backgroundColor: Color(0xFF8F2020),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF8F8),
      appBar: const RoyalAppBar(title: 'Notifications'),
      body: _checkingSubscription
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8F2020)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null && _error!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFBE123C), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFBE123C),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8F2020), Color(0xFFB43A3A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x228F2020),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x30000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isSubscribed ? Icons.notifications_active : Icons.notifications_off,
                          size: 36,
                          color: const Color(0xFF8F2020),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isSubscribed ? 'Notifications Enabled' : 'Notifications Disabled',
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSubscribed
                            ? 'You\'ll receive real-time updates for announcements, classes, results, and more.'
                            : 'Enable notifications to stay informed about important updates.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildActionButton(
                  text: _isSubscribed ? 'Disable Notifications' : 'Enable Notifications',
                  icon: _isSubscribed ? Icons.notifications_off : Icons.notifications_active,
                  color: _isSubscribed ? const Color(0xFF8F2020) : const Color(0xFF246B4B),
                  onPressed: _isSubscribed ? _disableNotifications : _enableNotifications,
                  loading: _loading,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8DADA)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEEEE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Color(0xFF8F2020),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'About Notifications',
                            style: GoogleFonts.roboto(
                              color: const Color(0xFF252525),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        '📢 Announcements',
                        'New college announcements and notices',
                      ),
                      _buildInfoItem(
                        '📚 Classes & Results',
                        'Online class schedules, internal marks, and exam results',
                      ),
                      _buildInfoItem(
                        '📝 Doubts & Timetable',
                        'Doubt answers, timetable changes, and leave status',
                      ),
                      _buildInfoItem(
                        '🔒 Privacy',
                        'Your data is encrypted. Only you receive your notifications.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 20),
        label: Text(
          text,
          style: GoogleFonts.roboto(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          shadowColor: color.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    color: const Color(0xFF252525),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF7A7A7A),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}