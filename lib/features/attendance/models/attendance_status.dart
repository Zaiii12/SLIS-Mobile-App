/// Maps directly to the P/L/A buttons in the design and the `status` field
/// on `POST /api/attendance/bulk/`.
enum AttendanceStatus { present, late, absent }

extension AttendanceStatusJson on AttendanceStatus {
  String toJson() {
    switch (this) {
      case AttendanceStatus.present:
        return 'present';
      case AttendanceStatus.late:
        return 'late';
      case AttendanceStatus.absent:
        return 'absent';
    }
  }

  static AttendanceStatus fromJson(String value) {
    switch (value) {
      case 'late':
        return AttendanceStatus.late;
      case 'absent':
        return AttendanceStatus.absent;
      default:
        return AttendanceStatus.present;
    }
  }
}
