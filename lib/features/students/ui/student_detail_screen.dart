import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/state/auth_provider.dart';
import '../../billing/data/enrollment_repository.dart';
import '../../billing/models/enrollment.dart';
import '../data/students_repository.dart';
import '../models/student.dart';
import 'student_status_pill.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.student});

  final Student student;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late Student _student;
  bool _editing = false;
  bool _saving = false;
  String? _error;
  String? _latestEnrollmentStatus;
  bool _loadingEnrollment = true;

  late final _firstNameController = TextEditingController(text: _student.firstName);
  late final _middleNameController = TextEditingController(text: _student.middleName);
  late final _lastNameController = TextEditingController(text: _student.lastName);
  late final _addressController = TextEditingController(text: _student.address);
  late String _sex = _student.sex;
  late String _status = _student.status;
  late String _birthDate = _student.birthDate;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
    _loadLatestEnrollment();
  }

  Future<void> _loadLatestEnrollment() async {
    try {
      final enrollments = await context
          .read<EnrollmentRepository>()
          .fetchEnrollmentsForStudent(_student.id);
      if (!mounted) return;
      setState(() {
        _latestEnrollmentStatus = enrollments.isEmpty
            ? null
            : enrollments.first.enrollmentStatus;
        _loadingEnrollment = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingEnrollment = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool get _canEdit {
    final role = context.read<AuthProvider>().user?.role;
    return role == roleRegistrar || hasAnyRole(role, staffAdmin);
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _error = null;
      _firstNameController.text = _student.firstName;
      _middleNameController.text = _student.middleName;
      _lastNameController.text = _student.lastName;
      _addressController.text = _student.address;
      _sex = _student.sex;
      _status = _student.status;
      _birthDate = _student.birthDate;
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
    final updated = _student.copyWith(
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      address: _addressController.text.trim(),
      sex: _sex,
      status: _status,
      birthDate: _birthDate,
    );
    try {
      final repository = context.read<StudentsRepository>();
      final saved = await repository.updateStudent(_student.id, updated.toEditJson());
      if (!mounted) return;
      setState(() {
        _student = saved;
        _editing = false;
        _saving = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final isConflict = e.response?.statusCode == 400;
      setState(() {
        _saving = false;
        _error = isConflict
            ? 'This record was updated by someone else. Close and reopen to see the latest changes.'
            : "Couldn't save changes. Check your connection and try again.";
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final initial = DateTime.tryParse(_birthDate) ?? DateTime.now();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.cardWhite,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select birth date',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headingDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted3),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  surface: AppColors.cardWhite,
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  onSurface: AppColors.headingDark,
                ),
              ),
              child: CalendarDatePicker(
                initialDate: initial,
                firstDate: DateTime(1990),
                lastDate: DateTime.now(),
                onDateChanged: (picked) => Navigator.of(context).pop(picked),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _birthDate = picked.toIso8601String().split('T').first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Student Profile',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingDark,
          ),
        ),
        actions: [
          if (_canEdit && !_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit student',
              onPressed: _startEditing,
            ),
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _cancelEditing,
              child: Text(
                'Cancel',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: AppColors.textMuted3),
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
                    colors: [AppColors.avatarGradientStart, AppColors.avatarGradientEnd],
                  ),
                ),
                child: Center(
                  child: Text(
                    _student.initials,
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
                _student.name,
                style: GoogleFonts.dmSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'LRN ${_student.lrn}',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted3),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  StudentStatusPill(status: _student.statusValue, fontSize: 11),
                  if (_loadingEnrollment)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_latestEnrollmentStatus != null)
                    _EnrollmentStatusPill(status: _latestEnrollmentStatus!),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.interCardGap),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dangerText),
              ),
            ),
            const SizedBox(height: AppSpacing.interCardGap),
          ],
          if (_editing)
            _EditForm(
              firstNameController: _firstNameController,
              middleNameController: _middleNameController,
              lastNameController: _lastNameController,
              addressController: _addressController,
              sex: _sex,
              status: _status,
              birthDate: _birthDate,
              onSexChanged: (v) => setState(() => _sex = v),
              onStatusChanged: (v) => setState(() => _status = v),
              onPickBirthDate: _pickBirthDate,
            )
          else
            _InfoCard(
              title: 'Profile',
              rows: [
                _InfoRow('Birth Date', _student.birthDate),
                _InfoRow('Sex', _student.sex),
                _InfoRow('Address', _student.address, alignEnd: true),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.firstNameController,
    required this.middleNameController,
    required this.lastNameController,
    required this.addressController,
    required this.sex,
    required this.status,
    required this.birthDate,
    required this.onSexChanged,
    required this.onStatusChanged,
    required this.onPickBirthDate,
  });

  final TextEditingController firstNameController;
  final TextEditingController middleNameController;
  final TextEditingController lastNameController;
  final TextEditingController addressController;
  final String sex;
  final String status;
  final String birthDate;
  final ValueChanged<String> onSexChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onPickBirthDate;

  static const _sexOptions = ['male', 'female'];
  static const _statusOptions = ['active', 'inactive', 'transferred', 'graduated', 'dropped'];

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
              'Edit Profile',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.headingDark),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('First Name'),
                _BoxedTextField(controller: firstNameController),
                const SizedBox(height: 14),
                _FieldLabel('Middle Name'),
                _BoxedTextField(controller: middleNameController),
                const SizedBox(height: 14),
                _FieldLabel('Last Name'),
                _BoxedTextField(controller: lastNameController),
                const SizedBox(height: 14),
                _FieldLabel('Birth Date'),
                _BoxedTapField(value: birthDate, onTap: onPickBirthDate),
                const SizedBox(height: 14),
                _FieldLabel('Sex'),
                _BoxedDropdown(
                  value: sex,
                  items: _sexOptions,
                  onChanged: onSexChanged,
                ),
                const SizedBox(height: 14),
                _FieldLabel('Status'),
                _BoxedDropdown(
                  value: status,
                  items: _statusOptions,
                  onChanged: onStatusChanged,
                ),
                const SizedBox(height: 14),
                _FieldLabel('Address'),
                _BoxedTextField(controller: addressController, maxLines: 3),
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
  const _BoxedTextField({required this.controller, this.maxLines = 1});

  final TextEditingController controller;
  final int maxLines;

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
        maxLines: maxLines,
        style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.headingDark),
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

class _BoxedTapField extends StatelessWidget {
  const _BoxedTapField({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.input),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: Border.all(color: AppColors.inputBorder, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value.isEmpty ? 'Select date' : value,
              style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.headingDark),
            ),
            const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textMuted2),
          ],
        ),
      ),
    );
  }
}

class _BoxedDropdown extends StatelessWidget {
  const _BoxedDropdown({required this.value, required this.items, required this.onChanged});

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
          icon: const Icon(Icons.expand_more, size: 16, color: AppColors.textMuted2),
          borderRadius: BorderRadius.circular(AppRadii.input),
          style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.headingDark),
          items: [
            for (final item in items)
              DropdownMenuItem(value: item, child: Text(item[0].toUpperCase() + item.substring(1))),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

const _enrollmentStatusColors = {
  'enrolled': (AppColors.successBg, AppColors.successText),
  'pending': (AppColors.warningBg, AppColors.warningText2),
  'cancelled': (AppColors.dangerBg, AppColors.dangerText),
  'completed': (AppColors.neutralPillBg, AppColors.neutralPillText),
  'transferred_out': (AppColors.neutralPillBg, AppColors.neutralPillText),
};

class _EnrollmentStatusPill extends StatelessWidget {
  const _EnrollmentStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors =
        _enrollmentStatusColors[status] ??
        (AppColors.neutralPillBg, AppColors.neutralPillText);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        'Enrollment: ${enrollmentStatusLabel(status)}',
        style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: colors.$2),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value, {this.alignEnd = false});

  final String label;
  final String value;
  final bool alignEnd;
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
                          ? const Border(bottom: BorderSide(color: AppColors.rowDivider))
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i].label,
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted3),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            rows[i].value,
                            textAlign: rows[i].alignEnd ? TextAlign.right : TextAlign.left,
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
