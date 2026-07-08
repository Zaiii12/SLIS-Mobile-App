import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../stub_screen.dart';

class _NavItem {
  const _NavItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

const _navItems = [
  _NavItem(Icons.grid_view_outlined, 'Dashboard'),
  _NavItem(Icons.people_outline, 'Students'),
  _NavItem(Icons.event_available_outlined, 'Attendance'),
  _NavItem(Icons.description_outlined, 'Forms'),
  _NavItem(Icons.more_horiz, 'More'),
];

/// Bottom tab bar. Dashboard is the active landing tab; the other four are
/// stub destinations not yet designed, per the handoff.
class DashboardBottomNavBar extends StatelessWidget {
  const DashboardBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
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
          for (var i = 0; i < _navItems.length; i++)
            _NavButton(item: _navItems[i], isActive: i == 0),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.isActive});

  final _NavItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textMuted3;
    return InkWell(
      onTap: () {
        if (isActive) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StubScreen(title: item.label)),
        );
      },
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
