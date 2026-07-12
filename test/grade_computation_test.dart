import 'package:flutter_test/flutter_test.dart';
import 'package:slis_mobile/features/grades/models/grade_computation.dart';
import 'package:slis_mobile/features/grades/models/grading_component.dart';
import 'package:slis_mobile/features/grades/models/score_entry.dart';

ScoreEntry _entry({required int component, required double score, required double max}) {
  return ScoreEntry(
    id: 0,
    enrollmentId: 1,
    componentId: component,
    period: '1st_quarter',
    label: 'test',
    score: score,
    maxScore: max,
  );
}

void main() {
  test('matches the RBAC handoff formula for a passing grade', () {
    const components = [
      GradingComponent(id: 1, name: 'Written Work', weight: 30),
      GradingComponent(id: 2, name: 'Performance Task', weight: 50),
      GradingComponent(id: 3, name: 'Quarterly Exam', weight: 20),
    ];
    final entries = [
      _entry(component: 1, score: 18, max: 20), // 90%
      _entry(component: 2, score: 40, max: 50), // 80%
      _entry(component: 3, score: 35, max: 50), // 70%
    ];

    final result = computeGrade(components: components, entries: entries);

    // 90*0.3 + 80*0.5 + 70*0.2 = 27 + 40 + 14 = 81
    expect(result.finalGrade, closeTo(81, 0.001));
    expect(result.remarks, 'passed');
  });

  test('remarks is failed below 75', () {
    const components = [GradingComponent(id: 1, name: 'Written Work', weight: 100)];
    final entries = [_entry(component: 1, score: 70, max: 100)];

    final result = computeGrade(components: components, entries: entries);

    expect(result.finalGrade, closeTo(70, 0.001));
    expect(result.remarks, 'failed');
  });

  test('a component with no entries contributes zero but stays ungraded', () {
    const components = [
      GradingComponent(id: 1, name: 'Written Work', weight: 50),
      GradingComponent(id: 2, name: 'Performance Task', weight: 50),
    ];
    final entries = [_entry(component: 1, score: 100, max: 100)];

    final result = computeGrade(components: components, entries: entries);

    expect(result.breakdown[1].avgPercent, isNull);
    expect(result.breakdown[1].weighted, 0);
    expect(result.finalGrade, closeTo(50, 0.001)); // only component 1 contributes
  });

  test('averages multiple entries within the same component', () {
    const components = [GradingComponent(id: 1, name: 'Written Work', weight: 100)];
    final entries = [
      _entry(component: 1, score: 10, max: 10), // 100%
      _entry(component: 1, score: 5, max: 10), // 50%
    ];

    final result = computeGrade(components: components, entries: entries);

    expect(result.finalGrade, closeTo(75, 0.001)); // mean(100,50) = 75
    expect(result.remarks, 'passed'); // >= 75 is passed
  });
}
