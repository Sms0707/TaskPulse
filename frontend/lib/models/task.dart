import 'package:intl/intl.dart';

class Task {
  String id;
  String title;
  DateTime? deadline;
  DateTime? reminderTime;
  String priority;
  List<String> subtasks;
  bool isCompleted;
  DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.deadline,
    this.reminderTime,
    this.priority = 'Low',
    this.subtasks = const [],
    this.isCompleted = false,
    required this.createdAt,
  });

  String get overdueLabel {
    if (deadline == null || isCompleted) return "";
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(deadline!.year, deadline!.month, deadline!.day);

    if (taskDate.isBefore(today)) {
      final difference = today.difference(taskDate).inDays;
      if (difference == 1) return "(yesterday)";
      return "(${DateFormat('d MMM').format(deadline!)})";
    }
    return "";
  }
}
