import 'grading_component.dart';
import 'score_entry.dart';

/// One component's contribution to the final grade, for the breakdown list
/// shown after Compute.
class ComponentBreakdown {
  const ComponentBreakdown({required this.component, required this.avgPercent, required this.weighted});

  final GradingComponent component;

  /// Null when the component has no score entries yet.
  final double? avgPercent;
  final double weighted;
}

class ComputedGrade {
  const ComputedGrade({required this.breakdown, required this.finalGrade, required this.remarks});

  final List<ComponentBreakdown> breakdown;
  final double finalGrade;

  /// Null when nothing has been scored yet (final_grade == 0 with no
  /// entries anywhere) — matches the backend's own `/score-entries/compute/`
  /// action (confirmed in `grading/views.py`), which returns `remarks: null`
  /// in that case rather than labelling an ungraded student "failed".
  final String? remarks;
}

/// Client-side grade computation per the RBAC handoff formula, mirroring
/// the backend's own `/api/score-entries/compute/` action exactly (see
/// `grading/views.py::compute_grade`) so the UI can show a live preview
/// without a round trip while the teacher is still entering scores:
///   avg_pct (per component) = mean(score/max_score) × 100
///   weighted_contribution = avg_pct × (component.weight / 100)
///   final_grade = Σ weighted_contribution
///   remarks = null if final_grade == 0, else "passed" if >= 75 else "failed"
/// A component with no entries contributes 0 to the final grade but shows
/// as ungraded (null avgPercent) in the breakdown.
ComputedGrade computeGrade({
  required List<GradingComponent> components,
  required List<ScoreEntry> entries,
}) {
  final breakdown = <ComponentBreakdown>[];
  var finalGrade = 0.0;

  for (final component in components) {
    final componentEntries = entries.where((e) => e.componentId == component.id).toList();
    final avgPercent = componentEntries.isEmpty
        ? null
        : componentEntries.map((e) => e.percent).reduce((a, b) => a + b) / componentEntries.length;
    final weighted = (avgPercent ?? 0) * (component.weight / 100);
    finalGrade += weighted;
    breakdown.add(ComponentBreakdown(component: component, avgPercent: avgPercent, weighted: weighted));
  }

  return ComputedGrade(
    breakdown: breakdown,
    finalGrade: finalGrade,
    remarks: finalGrade == 0 ? null : (finalGrade >= 75 ? 'passed' : 'failed'),
  );
}
