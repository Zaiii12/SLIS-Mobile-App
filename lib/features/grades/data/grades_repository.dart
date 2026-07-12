import '../models/graded_student.dart';
import '../models/grading_component.dart';
import '../models/grading_template.dart';
import '../models/score_entry.dart';
import '../models/subject.dart';
import 'grades_api.dart';

class GradesRepository {
  GradesRepository(this._api);

  final GradesApi _api;

  Future<List<Subject>> fetchSubjects() => _api.fetchSubjects();

  Future<GradingTemplate?> fetchTemplateForLevel(String schoolLevel) =>
      _api.fetchTemplateForLevel(schoolLevel);

  Future<List<GradingComponent>> fetchComponents(int gradingTemplateId) =>
      _api.fetchComponents(gradingTemplateId);

  Future<List<GradedStudent>> fetchGradedRoster({
    required int sectionAdvisoryId,
    required int subjectId,
    required String period,
  }) =>
      _api.fetchGradedRoster(sectionAdvisoryId: sectionAdvisoryId, subjectId: subjectId, period: period);

  Future<List<ScoreEntry>> fetchScoreEntries({required int enrollmentId, required String period}) =>
      _api.fetchScoreEntries(enrollmentId: enrollmentId, period: period);

  Future<ScoreEntry> createScoreEntry({
    required int enrollmentId,
    required int componentId,
    required String period,
    required String label,
    required double score,
    required double maxScore,
  }) =>
      _api.createScoreEntry(
        enrollmentId: enrollmentId,
        componentId: componentId,
        period: period,
        label: label,
        score: score,
        maxScore: maxScore,
      );

  Future<ScoreEntry> updateScoreEntry({
    required int id,
    required String label,
    required double score,
    required double maxScore,
  }) =>
      _api.updateScoreEntry(id: id, label: label, score: score, maxScore: maxScore);

  Future<void> deleteScoreEntry(int id) => _api.deleteScoreEntry(id);

  Future<void> saveGrade({
    required int enrollmentId,
    required int subjectId,
    required String period,
    required double finalGrade,
    required String remarks,
  }) =>
      _api.saveGrade(
        enrollmentId: enrollmentId,
        subjectId: subjectId,
        period: period,
        finalGrade: finalGrade,
        remarks: remarks,
      );
}
