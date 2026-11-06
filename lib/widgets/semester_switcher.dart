import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SemesterSwitcher extends StatelessWidget {
  const SemesterSwitcher({
    super.key,
    required this.selectedSemester,
    required this.currentSemester,
    required this.accent,
    required this.onChanged,
  });

  final int selectedSemester;
  final int currentSemester;
  final Color accent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canGoBack = selectedSemester > 1;
    final canGoForward = selectedSemester < currentSemester;
    final isCurrent = selectedSemester == currentSemester;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE1E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080D2850),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _arrowButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Previous semester',
            enabled: canGoBack,
            onPressed: () => onChanged(selectedSemester - 1),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Semester $selectedSemester',
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCurrent ? 'Current semester' : 'Previous semester',
                  style: TextStyle(
                    color: isCurrent ? accent : AppTheme.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _arrowButton(
            icon: Icons.arrow_forward_ios_rounded,
            tooltip: 'Next semester',
            enabled: canGoForward,
            onPressed: () => onChanged(selectedSemester + 1),
          ),
        ],
      ),
    );
  }

  Widget _arrowButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      color: accent,
      disabledColor: const Color(0xFFAFB8C5),
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        backgroundColor:
            enabled ? accent.withValues(alpha: .09) : const Color(0xFFF4F6F9),
        disabledBackgroundColor: const Color(0xFFF4F6F9),
      ),
    );
  }
}
