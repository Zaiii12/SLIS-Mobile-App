/// `NarrativeReport.rating` — enrollment-service's `RATING_CHOICES`
/// (`grades/models.py`), a 3-value enum, not free text.
enum NarrativeRating { outstanding, satisfactory, needsImprovement }

extension NarrativeRatingJson on NarrativeRating {
  String toJson() {
    switch (this) {
      case NarrativeRating.outstanding:
        return 'outstanding';
      case NarrativeRating.satisfactory:
        return 'satisfactory';
      case NarrativeRating.needsImprovement:
        return 'needs_improvement';
    }
  }

  String get label {
    switch (this) {
      case NarrativeRating.outstanding:
        return 'Outstanding';
      case NarrativeRating.satisfactory:
        return 'Satisfactory';
      case NarrativeRating.needsImprovement:
        return 'Needs Improvement';
    }
  }
}

NarrativeRating narrativeRatingFromJson(String value) {
  switch (value) {
    case 'outstanding':
      return NarrativeRating.outstanding;
    case 'needs_improvement':
      return NarrativeRating.needsImprovement;
    default:
      return NarrativeRating.satisfactory;
  }
}
