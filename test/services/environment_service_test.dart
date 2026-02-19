import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_spotdl_manager/services/environment_service.dart';

void main() {
  group('EnvironmentService', () {
    late EnvironmentService envService;

    setUp(() {
      envService = EnvironmentService();
    });

    test('checking python returns a string or null', () async {
      final version = await envService.checkPython();
      debugPrint('Python version found: $version');
      expect(version, anyOf(isA<String>(), isNull));
    });

    test('checking ffmpeg returns a string or null', () async {
      final version = await envService.checkFFmpeg();
      debugPrint('FFmpeg version found: $version');
      expect(version, anyOf(isA<String>(), isNull));
    });

    test('checking spotdl returns a string or null', () async {
      final version = await envService.checkSpotDL();
      debugPrint('SpotDL version found: $version');
      expect(version, anyOf(isA<String>(), isNull));
    });

    test('checkAll contains required keys', () async {
      final env = await envService.checkAll();
      expect(env.containsKey('python'), true);
      expect(env.containsKey('ffmpeg'), true);
      expect(env.containsKey('spotdl'), true);
    });
  });
}
