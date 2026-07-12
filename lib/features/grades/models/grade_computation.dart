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
  final String remarks;
}

/// Client-side grade computation per the RBAC handoff formula:
///   avg_pct (per component) = mean(score/max_score) × 100
///   weighted_contribution = avg_pct × (component.weight / 100)
///   final_grade = Σ weighted_contribution
///   remarks = final_grade >= 75 ? "passed" : "failed"
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
    remarks: finalGrade >= 75 ? 'passed' : 'failed',
  );
}
