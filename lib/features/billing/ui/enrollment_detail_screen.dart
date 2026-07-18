import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/enrollment_repository.dart';
import '../models/enrollment.dart';
import 'billing_format.dart';

/// Registrar-facing enrollment detail + quick-edit (or read-only detail for
/// `accounting`/`admin`/`super_admin` — see [readOnly]). Only [section] and
/// [enrollmentStatus] are editable — see [Enrollment]'s doc comment for why
/// grade/school level/strand/semester stay display-only (changing them
/// requires the backend's `progression_override` flow, which needs the
/// web's eligibility panel, not a quick mobile toggle). Enrolling a brand
/// new student is entirely out of scope here — that multi-step flow
/// (eligibility check, transfer records, scholarships, invoice generation)
/// stays web-only.
class EnrollmentDetailScreen extends StatefulWidget {
  const EnrollmentDetailScreen({
    super.key,
    required this.repository,
    required this.enrollment,
    this.readOnly = false,
  });

  final EnrollmentRepository repository;
  final Enrollment enrollment;

  /// Hides the edit pencil entirely — see [EnrollmentsListScreen]'s doc
  /// comment for who gets read-only vs. quick-edit access.
  final bool readOnly;

  @override
  State<EnrollmentDetailScreen> createState() => _EnrollmentDetailScreenState();
}

class _EnrollmentDetailScreenState extends State<EnrollmentDetailScreen> {
  late Enrollment _enrollment;
  bool _editing = false;
  bool _saving = false;
  String? _error;
  bool _changed = false;

  late final _sectionController = TextEditingController(
    text: _enrollment.section,
  );
  late String _status = _enrollment.enrollmentStatus;

  @override
  void initState() {
    super.initState();
    _enrollment = widget.enrollment;
  }

  @override
  void dispose() {
    _sectionController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _error = null;
      _sectionController.text = _enrollment.section;
      _status = _enrollment.enrollmentStatus;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editing = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.updateEnrollment(
        _enrollment.enrollmentId,
        section: _sectionController.text.trim(),
        enrollmentStatus: _status,
      );
      if (!mounted) return;
      setState(() {
        _enrollment = saved;
        _editing = false;
        _saving = false;
        _changed = true;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final serverMessage = _extractErrorMessage(e.response?.data);
      setState(() {
        _saving = false;
        _error =
            serverMessage ??
            "Couldn't save changes. Check your connection and try again.";
      });
    }
  }

  /// DRF `ValidationError` responses are `{"field": ["message"]}` or
  /// `{"non_field_errors": ["message"]}` — surfaced as-is (e.g. the
  /// document-completeness gate on pending→enrolled) rather than a generic
  /// failure message, since the real reason is useful to the registrar.
  String? _extractErrorMessage(dynamic data) {
    if (data is! Map) return null;
    for (final value in data.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final style = enrollmentStatusStyle(_enrollment.enrollmentStatus);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: AppColors.dashboardBg,
        appBar: AppBar(
          title: Text(
            'Enrollment',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.headingDark,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          actions: [
            if (!_editing && !widget.readOnly)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit enrollment',
                onPressed: _startEditing,
              ),
            if (_editing)
              TextButton(
                onPressed: _saving ? null : _cancelEditing,
                child: Text(
                  'Cancel',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted3,
                  ),
                ),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          children: [
            Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.avatarGradientStart,
                        AppColors.avatarGradientEnd,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _enrollment.initials,
                      style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _enrollment.studentName,
                  style: GoogleFonts.dmSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'LRN ${_enrollment.lrn}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textMuted3,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    style.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: style.textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.interCardGap),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dangerText,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.interCardGap),
            ],
            _InfoCard(
              title: 'Enrollment',
              rows: [
                _InfoRow('School Year', _enrollment.schoolYear),
                _InfoRow(
                  'School Level',
                  _schoolLevelLabel(_enrollment.schoolLevel),
                ),
                _InfoRow('Grade Level', _enrollment.gradeLevel),
                if (_enrollment.strand != null)
                  _InfoRow('Strand', _enrollment.strand!),
                if (_enrollment.semester != null)
                  _InfoRow('Semester', _enrollment.semester!),
              ],
            ),
            const SizedBox(height: AppSpacing.interCardGap),
            if (_editing)
              _EditForm(
                sectionController: _sectionController,
                status: _status,
                onStatusChanged: (v) => setState(() => _status = v),
              )
            else
              _InfoCard(
                title: 'Section & Status',
                rows: [
                  _InfoRow('Section', _enrollment.section),
                  _InfoRow('Status', style.label),
                ],
              ),
            const SizedBox(height: AppSpacing.interCardGap),
            _InfoCard(
              title: 'Student',
              rows: [
                _InfoRow('Sex', _enrollment.sex),
                _InfoRow('Birth Date', _enrollment.birthDate),
                if (_enrollment.studentNumber != null)
                  _InfoRow('Student Number', _enrollment.studentNumber!),
              ],
            ),
            if (_editing) ...[
              const SizedBox(height: AppSpacing.interCardGap),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _schoolLevelLabel(String value) {
  switch (value) {
    case 'nursery':
      return 'Nursery';
    case 'kindergarten':
      return 'Kindergarten';
    case 'elementary':
      return 'Elementary';
    case 'junior_highschool':
      return 'Junior High School';
    case 'senior_highschool':
      return 'Senior High School';
    default:
      return value;
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.sectionController,
    required this.status,
    required this.onStatusChanged,
  });

  final TextEditingController sectionController;
  final String status;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Text(
              'Edit Section & Status',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('Section'),
                _BoxedTextField(controller: sectionController),
                const SizedBox(height: 14),
                _FieldLabel('Status'),
                _BoxedDropdown(
                  value: status,
                  items: enrollmentStatuses,
                  onChanged: onStatusChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted3),
      ),
    );
  }
}

class _BoxedTextField extends StatelessWidget {
  const _BoxedTextField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.dmSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.headingDark,
        ),
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _BoxedDropdown extends StatelessWidget {
  const _BoxedDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          icon: const Icon(
            Icons.expand_more,
            size: 16,
            color: AppColors.textMuted2,
          ),
          borderRadius: BorderRadius.circular(AppRadii.input),
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.headingDark,
          ),
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item,
                child: Text(enrollmentStatusLabel(item)),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: i != rows.length - 1
                          ? const Border(
                              bottom: BorderSide(color: AppColors.rowDivider),
                            )
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i].label,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.textMuted3,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            rows[i].value,
                            style: GoogleFonts.dmSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.headingDark,
                            ),
                          ),
                        ),
                      ],
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
