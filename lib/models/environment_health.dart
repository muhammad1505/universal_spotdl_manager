enum HealthLevel {
  healthy,
  warning,
  error,
  checking,
}

class EnvironmentComponent {
  const EnvironmentComponent({
    required this.name,
    required this.installed,
    this.version,
    this.required = true,
    this.hint,
  });

  final String name;
  final bool installed;
  final String? version;
  final bool required;
  final String? hint;
}

class EnvironmentHealthReport {
  const EnvironmentHealthReport({
    required this.platform,
    required this.level,
    required this.components,
    required this.message,
    required this.checkedAt,
  });

  final String platform;
  final HealthLevel level;
  final List<EnvironmentComponent> components;
  final String message;
  final DateTime checkedAt;

  bool get isHealthy => level == HealthLevel.healthy;
}
