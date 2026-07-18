/// A narrative-report rating category (e.g. "Academic Performance",
/// "Behavior & Conduct"), from enrollment-service's
/// `GET /api/narrative-categories/`. Admin/registrar-managed runtime data —
/// there is no fixed enum of categories, so this must always be fetched, not
/// hardcoded (`NarrativeCategoryViewSet` is `IsAdminRegistrarOrReadOnly`:
/// teachers can read but not write categories).
class NarrativeCategory {
  const NarrativeCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  factory NarrativeCategory.fromJson(Map<String, dynamic> json) {
    return NarrativeCategory(
      id: json['category_id'] as int,
      name: json['name'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  final int id;
  final String name;
  final int sortOrder;
}
