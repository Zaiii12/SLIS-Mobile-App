import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../advisory/models/section_advisory.dart';
import '../../attendance/ui/widgets/attendance_empty_states.dart';
import '../data/grades_repository.dart';
import '../models/grade_computation.dart';
import '../models/grading_component.dart';
import '../models/grading_period.dart';
import '../models/score_entry.dart';
import '../models/subject.dart';
import 'grade_colors.dart';

const _componentColors = [
  AppColors.primary,
  AppColors.infoBlueIcon,
  AppColors.successText2,
  AppColors.warningText,
];

enum _LoadStatus { loading, loaded, error }

/// Per-student grade entry screen: one card per grading component with its
/// score entries, an add/edit form, and a Final Grade card. Compute is
/// local-only; only Save persists via `POST /api/grades/` (per the
/// handoff's explicit design↔computation note). Pops `true` on a
/// successful save so the roster list can refresh its badge.
class GradeDetailScreen extends StatefulWidget {
  const GradeDetailScreen({
    super.key,
    required this.repository,
    required this.section,
    required this.subject,
    required this.period,
    required this.enrollmentId,
    required this.studentName,
  });

  final GradesRepository repository;
  final SectionAdvisory section;
  final Subject subject;
  final GradingPeriod period;
  final int enrollmentId;
  final String studentName;

  @override
  State<GradeDetailScreen> createState() => _GradeDetailScreenState();
}

class _GradeDetailScreenState extends State<GradeDetailScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  List<GradingComponent> _components = const [];
  List<ScoreEntry> _entries = const [];

  ComputedGrade? _computed;
  bool _saving = false;

  final Map<int, _DraftEntry> _drafts = {};
  final Map<int, int> _editingEntryId = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final template = await widget.repository.fetchTemplateForSubject(widget.subject.id);
      final components = template?.components ?? const <GradingComponent>[];
      final entries = await widget.repository.fetchScoreEntries(
        enrollmentId: widget.enrollmentId,
        subjectId: widget.subject.id,
        period: widget.period.toJson(),
      );
      if (!mounted) return;
      setState(() {
        _components = components;
        _entries = entries;
        _computed = null;
        _status = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.error);
    }
  }

  _DraftEntry _draftFor(int componentId) => _drafts[componentId] ??= _DraftEntry();

  Future<void> _addOrUpdateEntry(GradingComponent component) async {
    final draft = _draftFor(component.id);
    final score = double.tryParse(draft.score);
    final max = double.tryParse(draft.max);
    if (draft.label.trim().isEmpty || score == null || max == null || max <= 0 || score < 0 || score > max) {
      return;
    }

    final editingId = _editingEntryId[component.id];
    try {
      if (editingId != null) {
        final updated = await widget.repository.updateScoreEntry(
          id: editingId,
          label: draft.label.trim(),
          score: score,
          maxScore: max,
        );
        if (!mounted) return;
        setState(() {
          _entries = [for (final e in _entries) if (e.id == editingId) updated else e];
        });
      } else {
        final created = await widget.repository.createScoreEntry(
          enrollmentId: widget.enrollmentId,
          subjectId: widget.subject.id,
          componentId: component.id,
          period: widget.period.toJson(),
          label: draft.label.trim(),
          score: score,
          maxScore: max,
        );
        if (!mounted) return;
        setState(() => _entries = [..._entries, created]);
      }
      setState(() {
        _drafts[component.id] = _DraftEntry();
        _editingEntryId.remove(component.id);
        _computed = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save score entry.', style: GoogleFonts.dmSans())),
      );
    }
  }

  void _startEdit(GradingComponent component, ScoreEntry entry) {
    setState(() {
      _drafts[component.id] = _DraftEntry()
        ..label = entry.label
        ..score = _trimZero(entry.score)
        ..max = _trimZero(entry.maxScore);
      _editingEntryId[component.id] = entry.id;
    });
  }

  void _cancelEdit(int componentId) {
    setState(() {
      _drafts[componentId] = _DraftEntry();
      _editingEntryId.remove(componentId);
    });
  }

  Future<void> _deleteEntry(GradingComponent component, ScoreEntry entry) async {
    try {
      await widget.repository.deleteScoreEntry(entry.id);
      if (!mounted) return;
      setState(() {
        _entries = _entries.where((e) => e.id != entry.id).toList();
        if (_editingEntryId[component.id] == entry.id) {
          _drafts[component.id] = _DraftEntry();
          _editingEntryId.remove(component.id);
        }
        // Deleting invalidates any prior compute, per the handoff.
        _computed = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete score entry.', style: GoogleFonts.dmSans())),
      );
    }
  }

  void _compute() {
    setState(() => _computed = computeGrade(components: _components, entries: _entries));
  }

  Future<void> _save() async {
    final computed = _computed;
    final remarks = computed?.remarks;
    // remarks is null only when nothing has been scored yet — the backend's
    // `Grade.remarks` field has no meaningful value to write in that case
    // (see grade_computation.dart), so Save has nothing valid to send.
    if (computed == null || remarks == null) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveGrade(
        enrollmentId: widget.enrollmentId,
        subjectId: widget.subject.id,
        period: widget.period.toJson(),
        numericGrade: computed.finalGrade,
        remarks: remarks,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed. Check your connection and try again.', style: GoogleFonts.dmSans())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          widget.studentName,
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.headingDark),
        ),
      ),
      body: _buildBody(),
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
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
          children: [
            for (var i = 0; i < _components.length; i++) ...[
              _ComponentCard(
                component: _components[i],
                color: _componentColors[i % _componentColors.length],
                entries: _entries.where((e) => e.componentId == _components[i].id).toList(),
                draft: _draftFor(_components[i].id),
                isEditing: _editingEntryId.containsKey(_components[i].id),
                onDraftChanged: () => setState(() {}),
                onEdit: (entry) => _startEdit(_components[i], entry),
                onDelete: (entry) => _deleteEntry(_components[i], entry),
                onAdd: () => _addOrUpdateEntry(_components[i]),
                onCancelEdit: () => _cancelEdit(_components[i].id),
              ),
              const SizedBox(height: AppSpacing.interCardGap),
            ],
            _FinalGradeCard(
              computed: _computed,
              saving: _saving,
              onCompute: _components.isEmpty ? null : _compute,
              onSave: _computed?.remarks == null ? null : _save,
            ),
          ],
        );
    }
  }
}

String _trimZero(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

class _DraftEntry {
  String label = '';
  String score = '';
  String max = '';
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({
    required this.component,
    required this.color,
    required this.entries,
    required this.draft,
    required this.isEditing,
    required this.onDraftChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
    required this.onCancelEdit,
  });

  final GradingComponent component;
  final Color color;
  final List<ScoreEntry> entries;
  final _DraftEntry draft;
  final bool isEditing;
  final VoidCallback onDraftChanged;
  final ValueChanged<ScoreEntry> onEdit;
  final ValueChanged<ScoreEntry> onDelete;
  final VoidCallback onAdd;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    final avgPercent = entries.isEmpty
        ? null
        : entries.map((e) => e.percent).reduce((a, b) => a + b) / entries.length;

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.rowDivider))),
            child: Row(
              children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                const SizedBox(width: 8),
                Text(
                  component.name,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.headingDark),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF9F4F4), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '${component.weight.toStringAsFixed(0)}%',
                    style: GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.textMuted2),
                  ),
                ),
                const Spacer(),
                if (avgPercent != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(
                      color: gradeBackground(avgPercent),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      '${avgPercent.toStringAsFixed(0)}%',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: gradeForeground(avgPercent),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (entries.isEmpty) const NoScoresEnteredState(),
                for (final entry in entries) ...[
                  _EntryRow(
                    entry: entry,
                    isEditing: isEditing,
                    onTap: () => onEdit(entry),
                    onDelete: () => onDelete(entry),
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _DraftField(
                        hint: 'e.g. Quiz 1',
                        value: draft.label,
                        onChanged: (v) {
                          draft.label = v;
                          onDraftChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 52,
                      child: _DraftField(
                        hint: 'Score',
                        value: draft.score,
                        alignEnd: true,
                        onChanged: (v) {
                          draft.score = v;
                          onDraftChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('/', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3)),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 48,
                      child: _DraftField(
                        hint: 'Max',
                        value: draft.max,
                        alignEnd: true,
                        onChanged: (v) {
                          draft.max = v;
                          onDraftChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isEditing)
                      TextButton(
                        onPressed: onCancelEdit,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.neutralPillBg,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neutralPillText),
                        ),
                      ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: onAdd,
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF0F0),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(
                        isEditing ? 'Save' : 'Add',
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftField extends StatelessWidget {
  const _DraftField({required this.hint, required this.value, required this.onChanged, this.alignEnd = false});

  final String hint;
  final String value;
  final bool alignEnd;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.headingDark),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(fontSize: 12, color: AppColors.iconMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        filled: true,
        fillColor: AppColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFDE2DE), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFDE2DE), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.isEditing, required this.onTap, required this.onDelete});

  final ScoreEntry entry;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isEditing ? const Color(0xFFFFF0F0) : const Color(0xFFFDFAFA),
          border: Border.all(color: isEditing ? const Color(0xFFFCA5A5) : AppColors.cardBorder),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.label,
                style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.headingDark),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${_trimZero(entry.score)}/${_trimZero(entry.maxScore)}',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF5A4A4A)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: gradeBackground(entry.percent),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${entry.percent.toStringAsFixed(0)}%',
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: gradeForeground(entry.percent)),
              ),
            ),
            InkWell(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.delete_outline, size: 15, color: AppColors.dangerText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinalGradeCard extends StatelessWidget {
  const _FinalGradeCard({required this.computed, required this.saving, required this.onCompute, required this.onSave});

  final ComputedGrade? computed;
  final bool saving;
  final VoidCallback? onCompute;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Final Grade',
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.headingDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Compute weighted grade from scores above',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                    ),
                  ],
                ),
              ),
              if (computed != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: gradeBackground(computed!.finalGrade),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    computed!.finalGrade.toStringAsFixed(2),
                    style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: gradeForeground(computed!.finalGrade)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCompute,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Compute', style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ),
              if (computed != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: saving ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    child: saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                          )
                        : Text('Save Grade', style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
          if (computed != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.cardBorder),
            const SizedBox(height: 8),
            for (var i = 0; i < computed!.breakdown.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _componentColors[i % _componentColors.length],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        computed!.breakdown[i].component.name,
                        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.headingDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(computed!.breakdown[i].avgPercent ?? 0).toStringAsFixed(1)}% × ${computed!.breakdown[i].component.weight.toStringAsFixed(0)}%',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        computed!.breakdown[i].weighted.toStringAsFixed(2),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.headingDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            const Divider(height: 1, color: AppColors.cardBorder),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Remarks',
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.headingDark),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: computed!.remarks == 'passed' ? AppColors.successBg2 : AppColors.dangerBg2,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    computed!.remarks ?? 'Not yet graded',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: computed!.remarks == 'passed' ? AppColors.successText2 : AppColors.dangerText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
