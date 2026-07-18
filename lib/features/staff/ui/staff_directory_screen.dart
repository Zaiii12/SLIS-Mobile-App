import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../attendance/ui/widgets/attendance_empty_states.dart';
import '../data/staff_repository.dart';
import '../models/staff_member.dart';
import 'staff_detail_screen.dart';

enum _LoadStatus { loading, loaded, error }

const _kAllRoles = 'all';
const _roleLabels = {
  'super_admin': 'Super Admin',
  'admin': 'Admin',
  'registrar': 'Registrar',
  'teacher': 'Teacher',
  'accounting': 'Accounting',
  'guardian': 'Guardian',
};

/// Read-only staff directory (admin/super_admin only, matching
/// `GET /api/auth/users/`'s `ADMIN_ROLES` gate). Deliberately no
/// create/edit/delete — account and role management stays on the ASIA
/// website; this is a fast "who has access, and what's their email" lookup
/// for when an admin isn't at a laptop, same "quick action" framing as the
/// rest of the mobile app's admin surface (Monitoring, Audit Log).
class StaffDirectoryScreen extends StatefulWidget {
  const StaffDirectoryScreen({super.key, required this.repository});

  final StaffRepository repository;

  @override
  State<StaffDirectoryScreen> createState() => _StaffDirectoryScreenState();
}

class _StaffDirectoryScreenState extends State<StaffDirectoryScreen> {
  final _searchController = TextEditingController();
  _LoadStatus _status = _LoadStatus.loading;
  List<StaffMember> _staff = const [];
  String _query = '';
  String _role = _kAllRoles;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final staff = await widget.repository.fetchStaff();
      staff.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _status = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.error);
    }
  }

  List<String> get _availableRoles {
    final present = _staff.map((s) => s.role).toSet().toList();
    present.sort();
    return present;
  }

  bool _matches(StaffMember member) {
    if (_role != _kAllRoles && member.role != _role) return false;
    if (_query.isEmpty) return true;
    return member.name.toLowerCase().contains(_query) || member.email.toLowerCase().contains(_query);
  }

  List<StaffMember> get _filtered => _staff.where(_matches).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Staff Directory',
          style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.headingDark),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
          children: [
            _SearchField(controller: _searchController),
            if (_status == _LoadStatus.loaded && _availableRoles.length > 1) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: _RoleFilterDropdown(
                  value: _role,
                  roles: _availableRoles,
                  onChanged: (v) => setState(() => _role = v),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _LoadStatus.loading:
        return const LoadingSkeletonCard(height: 200);
      case _LoadStatus.error:
        return NetworkErrorState(onRetry: _load);
      case _LoadStatus.loaded:
        final filtered = _filtered;
        if (_staff.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Center(
              child: Text(
                'No staff accounts found',
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted1),
              ),
            ),
          );
        }
        if (filtered.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Center(
              child: Text(
                'No staff match this search',
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted1),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
            border: Border.all(color: AppColors.cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < filtered.length; i++)
                _StaffRow(
                  member: filtered[i],
                  showDivider: i != filtered.length - 1,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => StaffDetailScreen(member: filtered[i])),
                  ),
                ),
            ],
          ),
        );
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.headingDark),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintText: 'Search by name or email',
          hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted3),
          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted3),
        ),
      ),
    );
  }
}

/// Tappable pill that opens a bottom-sheet picker list, matching Financial
/// Stats' `_MethodFilterChip` pattern — avoids a horizontally-scrolling chip
/// row silently clipping options off-screen once there are enough roles to
/// overflow the row (as a plain chip row did here with 5 roles).
class _RoleFilterDropdown extends StatelessWidget {
  const _RoleFilterDropdown({required this.value, required this.roles, required this.onChanged});

  final String value;
  final List<String> roles;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = {_kAllRoles: 'All roles', for (final role in roles) role: _roleLabels[role] ?? role};
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in options.entries)
                  ListTile(
                    dense: true,
                    title: Text(entry.value, style: GoogleFonts.dmSans(fontSize: 13)),
                    trailing: entry.key == value
                        ? const Icon(Icons.check, size: 18, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(entry.key),
                  ),
              ],
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value == _kAllRoles ? AppColors.neutralPillBg : AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: value == _kAllRoles ? Border.all(color: AppColors.cardBorder) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              options[value] ?? 'All roles',
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: value == _kAllRoles ? AppColors.textMuted1 : Colors.white,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 15,
              color: value == _kAllRoles ? AppColors.textMuted1 : Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.member, required this.showDivider, required this.onTap});

  final StaffMember member;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: showDivider ? const Border(bottom: BorderSide(color: AppColors.rowDivider)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFDF3F2)),
              child: Center(
                child: Text(
                  member.initials,
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name.isEmpty ? 'Unnamed' : member.name,
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    member.email,
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.neutralPillBg,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                _roleLabels[member.role] ?? member.role,
                style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.neutralPillText),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 13, color: Color(0xFFD0B0B0)),
          ],
        ),
      ),
    );
  }
}
