import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analytics_snapshot.dart';
import '../services/database_service.dart';
import '../services/file_service.dart';

class AnalyticsManager extends AsyncNotifier<AnalyticsSnapshot> {
  @override
  FutureOr<AnalyticsSnapshot> build() async {
    return ref.read(databaseServiceProvider).loadAnalytics();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref.read(databaseServiceProvider).loadAnalytics();
    });
  }

  Future<String> exportCsv() async {
    final csv = await ref.read(databaseServiceProvider).exportAnalyticsCsv();
    final file = await ref.read(fileServiceProvider).exportAnalyticsCsv(csv);
    return file.path;
  }
}

final analyticsProvider =
    AsyncNotifierProvider<AnalyticsManager, AnalyticsSnapshot>(
  AnalyticsManager.new,
);
