import '../../advisory/models/section_advisory.dart';
import '../models/graded_student.dart';
import '../models/grading_template.dart';
import '../models/score_entry.dart';
import '../models/subject.dart';
import 'grades_api.dart';

class GradesRepository {
  GradesRepository(this._api);

  final GradesApi _api;

  Future<List<Subject>> fetchSubjects({
    required SchoolLevel schoolLevel,
    required String gradeLevel,
    String? strand,
  }) =>
      _api.fetchSubjects(schoolLevel: schoolLevel, gradeLevel: gradeLevel, strand: strand);

  Future<List<Subject>> fetchAllSubjects() => _api.fetchAllSubjects();

  Future<GradingTemplate?> fetchTemplateForSubject(int subjectId) =>
      _api.fetchTemplateForSubject(subjectId);

  Future<List<GradedStudent>> fetchGradedRoster({
    required SectionAdvisory section,
    required int subjectId,
    required String period,
  }) =>
      _api.fetchGradedRoster(section: section, subjectId: subjectId, period: period);

  Future<List<Grade>> fetchGradesForEnrollment(int enrollmentId) =>
      _api.fetchGradesForEnrollment(enrollmentId);

  Future<List<ScoreEntry>> fetchScoreEntries({
    required int enrollmentId,
    required int subjectId,
    required String period,
  }) =>
      _api.fetchScoreEntries(enrollmentId: enrollmentId, subjectId: subjectId, period: period);

  Future<ScoreEntry> createScoreEntry({
    required int enrollmentId,
    required int subjectId,
    required int componentId,
    required String period,
    required String label,
    required double score,
    required double maxScore,
  }) =>
      _api.createScoreEntry(
        enrollmentId: enrollmentId,
        subjectId: subjectId,
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
    required double numericGrade,
    required String remarks,
  }) =>
      _api.saveGrade(
        enrollmentId: enrollmentId,
        subjectId: subjectId,
        period: period,
        numericGrade: numericGrade,
        remarks: remarks,
      );
}
