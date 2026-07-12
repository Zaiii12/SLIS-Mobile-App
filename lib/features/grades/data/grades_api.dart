import 'package:dio/dio.dart';

import '../../advisory/models/section_advisory.dart';
import '../../attendance/models/roster_entry.dart';
import '../models/graded_student.dart';
import '../models/grading_template.dart';
import '../models/score_entry.dart';
import '../models/subject.dart';

List<Map<String, dynamic>> _resultsOf(dynamic data) {
  final results = data is Map<String, dynamic> ? data['results'] as List? : data as List?;
  return (results ?? []).cast<Map<String, dynamic>>();
}

/// Calls enrollment-service's Grades endpoints per the real backend
/// (confirmed against `grades/`, `grading/`, `subjects/`, and
/// `enrollments/` app code — the RBAC handoff's documented shapes for this
/// feature turned out to differ substantially from what's actually
/// implemented). Score entries and final grades are gated by
/// `IsAdvisoryTeacherOrStaff`; subjects/templates are read-open to any
/// authenticated user.
class GradesApi {
  GradesApi(this._enrollment);

  final Dio _enrollment;

  Future<List<Subject>> fetchSubjects({required SchoolLevel schoolLevel}) async {
    final response = await _enrollment.get(
      '/api/subjects/',
      queryParameters: {'school_level': schoolLevelToJson(schoolLevel), 'page_size': 500},
    );
    return _resultsOf(response.data).map(Subject.fromJson).toList();
  }

  /// A `Subject`'s `grading_template_detail` already embeds the template's
  /// weighted `components` (see `subjects/serializers.py`) — no separate
  /// `/api/grading-templates/` or `/api/grading-components/` fetch needed.
  /// Null if the subject has no grading template assigned.
  Future<GradingTemplate?> fetchTemplateForSubject(int subjectId) async {
    final response = await _enrollment.get('/api/subjects/$subjectId/');
    final data = response.data as Map<String, dynamic>;
    final detail = data['grading_template_detail'] as Map<String, dynamic>?;
    return detail == null ? null : GradingTemplate.fromJson(detail);
  }

  /// There is no single endpoint that returns a section's roster joined
  /// with grades, so this fetches the roster (same `/api/enrollments/`
  /// call Attendance uses, scoped by the section's own fields since there's
  /// no `section_advisory` filter) and the `Grade` rows for this
  /// subject/period (unfiltered by section — matched client-side by
  /// `enrollmentId`), then joins them.
  Future<List<GradedStudent>> fetchGradedRoster({
    required SectionAdvisory section,
    required int subjectId,
    required String period,
  }) async {
    final rosterResponse = await _enrollment.get(
      '/api/enrollments/',
      queryParameters: {
        'school_year': section.schoolYear,
        'school_level': schoolLevelToJson(section.schoolLevel),
        'grade_level': section.gradeLevel,
        'section': section.section,
        if (section.strand != null) 'strand': section.strand,
        'page_size': 500,
      },
    );
    final roster = _resultsOf(rosterResponse.data).map(RosterEntry.fromJson).toList();

    final gradesResponse = await _enrollment.get(
      '/api/grades/',
      queryParameters: {'subject': subjectId, 'grading_period': period, 'page_size': 500},
    );
    final grades = _resultsOf(gradesResponse.data).map(Grade.fromJson).toList();
    final gradeByEnrollment = {for (final g in grades) g.enrollmentId: g};

    return [
      for (final entry in roster)
        () {
          final grade = gradeByEnrollment[entry.enrollmentId];
          return grade == null
              ? GradedStudent.ungraded(enrollmentId: entry.enrollmentId, studentName: entry.studentName)
              : GradedStudent(
                  enrollmentId: entry.enrollmentId,
                  studentName: entry.studentName,
                  numericGrade: grade.numericGrade,
                  remarks: grade.remarks,
                );
        }(),
    ];
  }

  Future<List<ScoreEntry>> fetchScoreEntries({
    required int enrollmentId,
    required int subjectId,
    required String period,
  }) async {
    final response = await _enrollment.get(
      '/api/score-entries/',
      queryParameters: {
        'enrollment_id': enrollmentId,
        'subject_id': subjectId,
        'grading_period': period,
        'page_size': 500,
      },
    );
    return _resultsOf(response.data).map(ScoreEntry.fromJson).toList();
  }

  Future<ScoreEntry> createScoreEntry({
    required int enrollmentId,
    required int subjectId,
    required int componentId,
    required String period,
    required String label,
    required double score,
    required double maxScore,
  }) async {
    final response = await _enrollment.post(
      '/api/score-entries/',
      data: {
        'enrollment': enrollmentId,
        'subject': subjectId,
        'grading_component': componentId,
        'grading_period': period,
        'label': label,
        'score': score,
        'max_score': maxScore,
      },
    );
    return ScoreEntry.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ScoreEntry> updateScoreEntry({
    required int id,
    required String label,
    required double score,
    required double maxScore,
  }) async {
    final response = await _enrollment.patch(
      '/api/score-entries/$id/',
      data: {'label': label, 'score': score, 'max_score': maxScore},
    );
    return ScoreEntry.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteScoreEntry(int id) async {
    await _enrollment.delete('/api/score-entries/$id/');
  }

  /// Per `grades/serializers.py`: the field is `numeric_grade` (not
  /// `final_grade`), and `remarks` must be one of "passed"/"failed"/
  /// "incomplete"/"dropped" — never null on write (the compute-time null
  /// case only applies before anything is scored, at which point Save is
  /// disabled in the UI).
  Future<void> saveGrade({
    required int enrollmentId,
    required int subjectId,
    required String period,
    required double numericGrade,
    required String remarks,
  }) async {
    await _enrollment.post(
      '/api/grades/',
      data: {
        'enrollment': enrollmentId,
        'subject': subjectId,
        'grading_period': period,
        'numeric_grade': numericGrade,
        'remarks': remarks,
      },
    );
  }
}
