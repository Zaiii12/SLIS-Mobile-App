import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/students_repository.dart';
import '../models/student.dart';
import 'student_detail_screen.dart';

// Level-based filter chips (Elementary/JHS/SHS) from the design mock were
// dropped — the real /api/students/ response has no level field (it lives
// on the enrollment record in enrollment-service, not the student record).
enum _StudentFilter { all, active, inactive }

extension on _StudentFilter {
  String get label {
    switch (this) {
      case _StudentFilter.all:
        return 'All';
      case _StudentFilter.active:
        return 'Active';
      case _StudentFilter.inactive:
        return 'Inactive';
    }
  }

  String? get statusParam {
    switch (this) {
      case _StudentFilter.active:
        return 'active';
      case _StudentFilter.inactive:
        return 'inactive';
      default:
        return null;
    }
  }
}

enum _LoadStatus { loading, loaded, error }

/// Students tab: search + filter chips + list, per the design mock. Teacher
/// role is read-only (no write actions exist in this UI regardless of
/// role — the RBAC handoff documents no student write endpoints yet).
class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({super.key, required this.repository});

  final StudentsRepository repository;

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  final _searchController = TextEditingController();
  _StudentFilter _filter = _StudentFilter.all;
  _LoadStatus _status = _LoadStatus.loading;
  List<Student> _students = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final students = await widget.repository.fetchStudents(
        search: _searchController.text.trim(),
        status: _filter.statusParam,
      );
      if (!mounted) return;
      setState(() {
        _students = students;
        _status = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.error);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  void _onFilterSelected(_StudentFilter filter) {
    setState(() => _filter = filter);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              controller: _searchController,
              onChanged: _onSearchChanged,
              filter: _filter,
              onFilterSelected: _onFilterSelected,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadStatus.error:
        return _ErrorState(onRetry: _load);
      case _LoadStatus.loaded:
        if (_students.isEmpty) return const _EmptyState();
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _students.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.rowDivider),
          itemBuilder: (context, index) => _StudentRow(student: _students[index]),
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onChanged,
    required this.filter,
    required this.onFilterSelected,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final _StudentFilter filter;
  final ValueChanged<_StudentFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Students',
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.headingDark,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF2D1A1A)),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search name or LRN',
              hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.iconMuted),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.iconMuted),
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _StudentFilter.values) ...[
                  _FilterChip(
                    label: f.label,
                    selected: f == filter,
                    onTap: () => onFilterSelected(f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.neutralPillBg,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: selected ? null : Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textMuted1,
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final statusBg = student.isActive ? AppColors.successBg : AppColors.neutralPillBg;
    final statusColor = student.isActive ? AppColors.successText : AppColors.neutralPillText;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFDF3F2),
              ),
              child: Center(
                child: Text(
                  student.initials,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    student.lrn,
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                student.isActive ? 'Active' : 'Inactive',
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, size: 28, color: Color(0xFFD8B8B4)),
            const SizedBox(height: 8),
            Text(
              'No students found',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Try a different name or LRN',
              style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted3),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 28, color: Color(0xFFD8B8B4)),
            const SizedBox(height: 8),
            Text(
              "Couldn't load students",
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted1,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
