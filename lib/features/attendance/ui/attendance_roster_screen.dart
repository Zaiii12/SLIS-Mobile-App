import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../advisory/models/section_advisory.dart';
import '../data/attendance_repository.dart';
import '../models/attendance_status.dart';
import '../models/roster_entry.dart';
import 'widgets/attendance_empty_states.dart';

enum _LoadStatus { loading, loaded, error }

/// Roster view for a single section/date: pre-populates P/L/A from any
/// existing records, defaults unrecorded students to present, and submits
/// the whole section in one `POST /api/attendance/bulk/` call. Pops `true`
/// on a successful submit so the section list can flip the "Marked" badge
/// without a full re-fetch.
class AttendanceRosterScreen extends StatefulWidget {
  const AttendanceRosterScreen({
    super.key,
    required this.repository,
    required this.section,
    required this.date,
  });

  final AttendanceRepository repository;
  final SectionAdvisory section;
  final DateTime date;

  @override
  State<AttendanceRosterScreen> createState() => _AttendanceRosterScreenState();
}

class _AttendanceRosterScreenState extends State<AttendanceRosterScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  List<RosterEntry> _roster = const [];
  final Map<int, AttendanceStatus> _marks = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final results = await Future.wait([
        widget.repository.fetchRoster(widget.section.id),
        widget.repository.fetchExisting(sectionAdvisoryId: widget.section.id, date: widget.date),
      ]);
      final roster = results[0] as List<RosterEntry>;
      final existing = results[1] as Map<int, AttendanceStatus>;
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _marks
          ..clear()
          ..addAll({
            for (final entry in roster)
              entry.enrollmentId: existing[entry.enrollmentId] ?? AttendanceStatus.present,
          });
        _status = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.error);
    }
  }

  void _setMark(int enrollmentId, AttendanceStatus status) {
    setState(() => _marks[enrollmentId] = status);
  }

  void _markAllPresent() {
    setState(() {
      for (final entry in _roster) {
        _marks[entry.enrollmentId] = AttendanceStatus.present;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.repository.submitBulk(marks: _marks, date: widget.date);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed. Check your connection and try again.', style: GoogleFonts.dmSans())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.section.displayName,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_roster.length} students · ${DateFormat('MMMM d').format(widget.date)}',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
            ),
          ],
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _status == _LoadStatus.loaded ? _buildSubmitBar() : null,
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadStatus.error:
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
          child: NetworkErrorState(onRetry: _load),
        );
      case _LoadStatus.loaded:
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
              ),
              child: InkWell(
                onTap: _markAllPresent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Mark all Present',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _roster.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.rowDivider),
                itemBuilder: (context, index) {
                  final entry = _roster[index];
                  return _RosterRow(
                    entry: entry,
                    status: _marks[entry.enrollmentId] ?? AttendanceStatus.present,
                    onChanged: (status) => _setMark(entry.enrollmentId, status),
                  );
                },
              ),
            ),
          ],
        );
    }
  }

  Widget _buildSubmitBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                )
              : Text('Submit Attendance (${_marks.length} marked)'),
        ),
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.entry, required this.status, required this.onChanged});

  final RosterEntry entry;
  final AttendanceStatus status;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFDF3F2)),
            child: Center(
              child: Text(
                entry.initials,
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.studentName,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              _MarkButton(
                label: 'P',
                active: status == AttendanceStatus.present,
                activeBg: AppColors.successFill,
                onTap: () => onChanged(AttendanceStatus.present),
              ),
              const SizedBox(width: 5),
              _MarkButton(
                label: 'L',
                active: status == AttendanceStatus.late,
                activeBg: AppColors.warningText,
                onTap: () => onChanged(AttendanceStatus.late),
              ),
              const SizedBox(width: 5),
              _MarkButton(
                label: 'A',
                active: status == AttendanceStatus.absent,
                activeBg: AppColors.primary,
                onTap: () => onChanged(AttendanceStatus.absent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.label,
    required this.active,
    required this.activeBg,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color activeBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 30,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeBg : AppColors.cardBorder,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textMuted3,
          ),
        ),
      ),
    );
  }
}
