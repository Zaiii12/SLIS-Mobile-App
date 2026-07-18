import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../app_shell.dart';

class _NavItem {
  const _NavItem(this.tab, this.icon, this.label);

  final ShellTab tab;
  final IconData icon;
  final String label;
}

const _allNavItems = [
  _NavItem(ShellTab.dashboard, Icons.grid_view_outlined, 'Dashboard'),
  _NavItem(ShellTab.students, Icons.people_outline, 'Students'),
  _NavItem(ShellTab.attendance, Icons.event_available_outlined, 'Attendance'),
  _NavItem(ShellTab.grades, Icons.menu_book_outlined, 'Grades'),
  _NavItem(ShellTab.monitoring, Icons.visibility_outlined, 'Monitoring'),
  _NavItem(ShellTab.auditLog, Icons.history, 'Audit Log'),
  _NavItem(ShellTab.financialStats, Icons.pie_chart_outline, 'Financials'),
  _NavItem(ShellTab.more, Icons.more_horiz, 'More'),
];

/// Persistent bottom tab bar owned by [AppShell]. Renders only the tabs
/// visible for the current role (e.g. `accounting` hides Students,
/// Attendance, and Grades per the RBAC handoff) and reports taps upward
/// instead of navigating itself.
class ShellBottomNavBar extends StatelessWidget {
  const ShellBottomNavBar({
    super.key,
    required this.selected,
    required this.visibleTabs,
    required this.onSelect,
  });

  final ShellTab selected;
  final List<ShellTab> visibleTabs;
  final ValueChanged<ShellTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = _allNavItems.where((item) => visibleTabs.contains(item.tab)).toList();

    return Container(
      padding: EdgeInsets.only(
        top: 9,
        bottom: 9 + MediaQuery.of(context).padding.bottom,
        left: 8,
        right: 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final item in items)
            _NavButton(
              item: item,
              isActive: item.tab == selected,
              onTap: () => onSelect(item.tab),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.isActive, required this.onTap});

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textMuted3;
    return InkWell(
      onTap: isActive ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 19, color: color),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: GoogleFonts.dmSans(
              fontSize: 9.5,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
