import 'package:dio/dio.dart';

import '../models/graded_student.dart';
import '../models/grading_component.dart';
import '../models/grading_template.dart';
import '../models/score_entry.dart';
import '../models/subject.dart';

List<Map<String, dynamic>> _resultsOf(dynamic data) {
  final results = data is Map<String, dynamic> ? data['results'] as List? : data as List?;
  return (results ?? []).cast<Map<String, dynamic>>();
}

/// Calls enrollment-service's Grades endpoints per the RBAC handoff. Score
/// entries and final grades are gated by `IsAdvisoryTeacherOrStaff`;
/// subjects/templates/components are read endpoints with no stated
/// restriction narrower than authenticated access.
class GradesApi {
  GradesApi(this._enrollment);

  final Dio _enrollment;

  Future<List<Subject>> fetchSubjects() async {
    final response = await _enrollment.get('/api/subjects/');
    return _resultsOf(response.data).map(Subject.fromJson).toList();
  }

  Future<GradingTemplate?> fetchTemplateForLevel(String schoolLevel) async {
    final response = await _enrollment.get(
      '/api/grading-templates/',
      queryParameters: {'school_level': schoolLevel},
    );
    final templates = _resultsOf(response.data).map(GradingTemplate.fromJson).toList();
    return templates.isEmpty ? null : templates.first;
  }

  Future<List<GradingComponent>> fetchComponents(int gradingTemplateId) async {
    final response = await _enrollment.get(
      '/api/grading-components/',
      queryParameters: {'grading_template': gradingTemplateId},
    );
    return _resultsOf(response.data).map(GradingComponent.fromJson).toList();
  }

  Future<List<GradedStudent>> fetchGradedRoster({
    required int sectionAdvisoryId,
    required int subjectId,
    required String period,
  }) async {
    final response = await _enrollment.get(
      '/api/grades/',
      queryParameters: {
        'section_advisory': sectionAdvisoryId,
        'subject': subjectId,
        'period': period,
      },
    );
    return _resultsOf(response.data).map(GradedStudent.fromJson).toList();
  }

  Future<List<ScoreEntry>> fetchScoreEntries({required int enrollmentId, required String period}) async {
    final response = await _enrollment.get(
      '/api/score-entries/',
      queryParameters: {'enrollment': enrollmentId, 'period': period},
    );
    return _resultsOf(response.data).map(ScoreEntry.fromJson).toList();
  }

  Future<ScoreEntry> createScoreEntry({
    required int enrollmentId,
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
        'component': componentId,
        'period': period,
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

  Future<void> saveGrade({
    required int enrollmentId,
    required int subjectId,
    required String period,
    required double finalGrade,
    required String remarks,
  }) async {
    await _enrollment.post(
      '/api/grades/',
      data: {
        'enrollment': enrollmentId,
        'subject': subjectId,
        'period': period,
        'final_grade': finalGrade,
        'remarks': remarks,
      },
    );
  }
}
