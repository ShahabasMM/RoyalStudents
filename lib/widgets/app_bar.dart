import 'package:flutter/material.dart';

class RoyalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const RoyalAppBar({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(
          Icons.arrow_back_rounded,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ============================================================
// BOTTOM NAVIGATION
// ============================================================

class BottomNav extends StatelessWidget {
  final int currentIndex;

  const BottomNav({
    super.key,
    required this.currentIndex,
  });

  // ============================================================
  // DARK BLUE THEME
  // ============================================================

  static const Color primary = Color(0xFF1E40AF);

  static const Color softBlue = Color(0xFFEFF6FF);

  static const Color textMuted = Color(0xFF64748B);

  // ============================================================
  // ROUTES
  // ============================================================

  void _go(
    BuildContext context,
    int index,
  ) {
    final routes = <String>[
      '/home',
      '/attendance',
      '/timetable',
      '/announcements',
      '/profile'
    ];

    if (index == currentIndex) return;

    Navigator.pushReplacementNamed(
      context,
      routes[index],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE8ECF2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _navItem(
                context,
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
              ),
              _navItem(
                context,
                index: 1,
                icon: Icons.fact_check_outlined,
                activeIcon: Icons.fact_check_rounded,
                label: 'Attendance',
              ),
              _navItem(
                context,
                index: 2,
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month_rounded,
                label: 'Timetable',
              ),
              _navItem(
                context,
                index: 3,
                icon: Icons.campaign_outlined,
                activeIcon: Icons.campaign_rounded,
                label: 'News',
              ),
              _navItem(
                context,
                index: 4,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NAV ITEM
  // ============================================================

  Widget _navItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool selected = currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _go(
          context,
          index,
        ),
        splashColor: primary.withValues(alpha: 0.06),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ==================================================
            // ICON CONTAINER
            // ==================================================

            AnimatedContainer(
              duration: const Duration(
                milliseconds: 180,
              ),
              width: selected ? 40 : 34,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? softBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: selected ? 21 : 20,
                color: selected ? primary : textMuted,
              ),
            ),

            const SizedBox(height: 3),

            // ==================================================
            // LABEL
            // ==================================================

            Text(
              label,
              style: TextStyle(
                color: selected ? primary : textMuted,
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
