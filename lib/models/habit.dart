class Habit {
  const Habit({
    this.id,
    required this.title,
    required this.description,
    required this.focusMinutes,
    required this.streak,
    this.completed = false,
  });

  final int? id;
  final String title;
  final String description;
  final int focusMinutes;
  final int streak;
  final bool completed;

  Habit copyWith({
    int? id,
    String? title,
    String? description,
    int? focusMinutes,
    int? streak,
    bool? completed,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      streak: streak ?? this.streak,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'focus_minutes': focusMinutes,
      'streak': streak,
      'completed': completed ? 1 : 0,
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }

  static Habit fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String,
      focusMinutes: map['focus_minutes'] as int,
      streak: map['streak'] as int,
      completed: (map['completed'] as int) == 1,
    );
  }
}
