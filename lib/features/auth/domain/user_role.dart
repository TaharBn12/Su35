/// الصفة المهنية للمستخدم — تُخزَّن في profiles.role بنفس القيم النصية.
enum UserRole { pilot, engineer, student, instructor, other }

/// القيمة النصية المخزَّنة في قاعدة البيانات.
extension UserRoleDb on UserRole {
  String get dbValue => name;
}

/// تحويل قيمة قادمة من قاعدة البيانات إلى [UserRole] بأمان.
UserRole userRoleFromDb(Object? value) {
  final String raw = value is String ? value : '';
  if (raw == UserRole.engineer.dbValue) {
    return UserRole.engineer;
  }
  if (raw == UserRole.student.dbValue) {
    return UserRole.student;
  }
  if (raw == UserRole.instructor.dbValue) {
    return UserRole.instructor;
  }
  if (raw == UserRole.other.dbValue) {
    return UserRole.other;
  }
  return UserRole.pilot;
}
