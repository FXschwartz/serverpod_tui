import 'package:nocterm/nocterm.dart' hide isEmpty;
import 'package:serverpod_tui/serverpod_tui.dart';
import 'package:test/test.dart';

final _time = DateTime(2026, 6, 8, 22, 6, 29, 29);

/// Renders [AlertLine] at [width] columns and returns the text of the rendered
/// line.
Future<String> _render(
  String message, {
  required int width,
  DateTime? time,
}) async {
  final tester = await NoctermTester.create(size: Size(width.toDouble(), 6));
  try {
    await tester.pumpComponent(
      AlertLine(alert: AlertMessage.parse(message), time: time),
    );
    return tester.terminalState
        .getText()
        .split('\n')
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
  } finally {
    tester.dispose();
  }
}

void main() {
  group('Given an alert with a copyable code', () {
    late String line;

    setUp(() async {
      line = await _render(
        'Registration code: <h2k9x3mp>',
        width: 80,
        time: _time,
      );
    });

    test('when rendered then the message shows without the brackets', () {
      expect(line, contains('Registration code: h2k9x3mp'));
    });

    test('when rendered then the copy and dismiss hints are shown', () {
      expect(line, contains('copy'));
      expect(line, contains('dismiss'));
    });

    test('when rendered then it is left-aligned with the alert marker', () {
      expect(line.startsWith('alert'), isTrue);
    });

    test('when a time is given then it shows in the log timestamp format', () {
      expect(line, contains('22:06:29.029'));
    });
  });

  group('Given an alert without a time', () {
    test(
      'when rendered then the message follows the marker directly',
      () async {
        final line = await _render('Registration code: <h2k9x3mp>', width: 80);

        // No timestamp column between the marker and the message.
        expect(line, startsWith('alert Registration code:'));
      },
    );
  });

  group('Given an alert without a code', () {
    late String line;

    setUp(() async {
      line = await _render('Server requires a restart', width: 80, time: _time);
    });

    test('when rendered then the message and dismiss hint are shown', () {
      expect(line, contains('Server requires a restart'));
      expect(line, contains('dismiss'));
    });

    test('when rendered then no copy hint is shown', () {
      expect(line, isNot(contains('copy')));
    });
  });

  group('Given an alert that fits the width', () {
    test('when rendered then it shows in full without an ellipsis', () async {
      final line = await _render(
        'Registration code: <h2k9x3mp>',
        width: 80,
        time: _time,
      );

      expect(line, contains('Registration code: h2k9x3mp'));
      expect(line, isNot(contains('…')));
    });
  });

  group('Given an alert wider than the width', () {
    late String line;

    setUp(() async {
      line = await _render(
        'A very long registration message that will not fit: <h2k9x3mp>',
        width: 64,
        time: _time,
      );
    });

    test('when rendered then the message is truncated with an ellipsis', () {
      expect(line, contains('…'));
    });

    test('when rendered then the trailing code stays visible', () {
      expect(line, contains('h2k9x3mp'));
    });

    test('when rendered then it stays within the width on one line', () {
      expect(line.trimRight().length, lessThanOrEqualTo(64));
    });
  });
}
