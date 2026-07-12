/// Maps to the P/L/A buttons in the design. The backend's `status` field
/// (both `AttendanceRecord.status` and the bulk endpoint) uses single-letter
/// codes: P (present), A (absent), L (late), E (excused) — confirmed against
/// `attendance/serializers.py`'s `BulkAttendanceItemSerializer` choices.
enum AttendanceStatus { present, late, absent }

extension AttendanceStatusJson on AttendanceStatus {
  String toJson() {
    switch (this) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.late:
        return 'L';
      case AttendanceStatus.absent:
        return 'A';
    }
  }

  static AttendanceStatus fromJson(String value) {
    switch (value) {
      case 'L':
        return AttendanceStatus.late;
      case 'A':
        return AttendanceStatus.absent;
      default:
        return AttendanceStatus.present;
    }
  }
}
