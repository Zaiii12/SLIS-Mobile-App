import '../../advisory/models/section_advisory.dart';

/// Grading period string values, from the design mock. Per the RBAC
/// handoff these are UNCONFIRMED against enrollment-service's actual
/// `period` enum — flagged there as "Confirm with backend" before shipping.
enum GradingPeriod {
  firstQuarter,
  secondQuarter,
  thirdQuarter,
  fourthQuarter,
  firstSemester,
  secondSemester,
}

extension GradingPeriodJson on GradingPeriod {
  String toJson() {
    switch (this) {
      case GradingPeriod.firstQuarter:
        return '1st_quarter';
      case GradingPeriod.secondQuarter:
        return '2nd_quarter';
      case GradingPeriod.thirdQuarter:
        return '3rd_quarter';
      case GradingPeriod.fourthQuarter:
        return '4th_quarter';
      case GradingPeriod.firstSemester:
        return '1st_semester';
      case GradingPeriod.secondSemester:
        return '2nd_semester';
    }
  }

  String get label {
    switch (this) {
      case GradingPeriod.firstQuarter:
        return '1st Quarter';
      case GradingPeriod.secondQuarter:
        return '2nd Quarter';
      case GradingPeriod.thirdQuarter:
        return '3rd Quarter';
      case GradingPeriod.fourthQuarter:
        return '4th Quarter';
      case GradingPeriod.firstSemester:
        return '1st Semester';
      case GradingPeriod.secondSemester:
        return '2nd Semester';
    }
  }
}

const _quarterPeriods = [
  GradingPeriod.firstQuarter,
  GradingPeriod.secondQuarter,
  GradingPeriod.thirdQuarter,
  GradingPeriod.fourthQuarter,
];
const _semesterPeriods = [GradingPeriod.firstSemester, GradingPeriod.secondSemester];

/// Derives the available period options from a [SectionAdvisory]'s
/// school level, per the RBAC handoff's grading-periods table.
List<GradingPeriod> periodsForSchoolLevel(SchoolLevel level) {
  return level == SchoolLevel.seniorHighschool ? _semesterPeriods : _quarterPeriods;
}
