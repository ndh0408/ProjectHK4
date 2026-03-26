/// Smart greeting utilities based on time of day
class SmartGreeting {
  SmartGreeting._();

  /// Get greeting based on current time
  static String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  /// Get greeting with name
  static String getGreetingWithName(String? name) {
    final greeting = getGreeting();
    if (name != null && name.isNotEmpty) {
      return '$greeting, $name';
    }
    return greeting;
  }

  /// Get greeting emoji
  static String getGreetingEmoji() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return '☀️';
    } else if (hour >= 12 && hour < 17) {
      return '🌤️';
    } else if (hour >= 17 && hour < 21) {
      return '🌅';
    } else {
      return '🌙';
    }
  }

  /// Get motivational message based on time
  static String getMotivationalMessage() {
    final hour = DateTime.now().hour;
    final dayOfWeek = DateTime.now().weekday;

    // Weekend messages
    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
      if (hour >= 5 && hour < 12) {
        return 'Perfect weekend morning for events!';
      } else if (hour >= 12 && hour < 17) {
        return 'Enjoy your weekend activities!';
      } else {
        return 'Wind down with some exciting events!';
      }
    }

    // Weekday messages
    if (hour >= 5 && hour < 12) {
      return 'Start your day with something exciting!';
    } else if (hour >= 12 && hour < 17) {
      return 'Take a break and explore new events!';
    } else if (hour >= 17 && hour < 21) {
      return 'Perfect time for after-work activities!';
    } else {
      return 'Plan your upcoming adventures!';
    }
  }

  /// Get subtitle for home screen
  static String getHomeSubtitle() {
    final dayOfWeek = DateTime.now().weekday;
    final isWeekend =
        dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday;

    if (isWeekend) {
      return 'Discover amazing weekend events near you';
    }
    return 'Discover amazing events near you';
  }
}
