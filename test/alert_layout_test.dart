import 'package:nocterm/nocterm.dart' hide isEmpty;
import 'package:serverpod_tui/serverpod_tui.dart';
import 'package:test/test.dart';

import 'util.dart';

/// Renders [alert] in an app sized to [width] columns and returns the text of
/// the bottom row (where the alert is pinned).
Future<String> _renderAlert(AlertMessage alert, {required int width}) async {
  final state = TestState();
  final holder = TestStateHolder(state);
  final tester = await NoctermTester.create(size: Size(width.toDouble(), 10));
  try {
    await tester.pumpComponent(TestApp(holder: holder));
    holder.showAlert(alert);
    await tester.pump(const Duration(milliseconds: 100));

    return tester.terminalState
        .getText()
        .split('\n')
        .lastWhere((line) => line.trim().isNotEmpty, orElse: () => '');
  } finally {
    tester.dispose();
    await holder.dispose();
  }
}

void main() {
  group('Given an alert wider than the terminal', () {
    late String line;

    setUp(() async {
      line = await _renderAlert(
        AlertMessage.parse(
          'A very long registration message that will not fit: <h2k9x3mp>',
        ),
        width: 50,
      );
    });

    test('when rendered then the message is truncated with an ellipsis', () {
      expect(line, contains('…'));
    });

    test('when rendered then the trailing code stays visible', () {
      expect(line, contains('h2k9x3mp'));
    });

    test('when rendered then it fits on a single row within the width', () {
      expect(line.trimRight().length, lessThanOrEqualTo(50));
    });
  });

  group('Given an alert that fits the terminal', () {
    late String line;

    setUp(() async {
      line = await _renderAlert(
        AlertMessage.parse('Registration code: <h2k9x3mp>'),
        width: 80,
      );
    });

    test(
      'when rendered then the message shows in full without an ellipsis',
      () {
        expect(line, contains('Registration code: h2k9x3mp'));
        expect(line, isNot(contains('…')));
      },
    );

    test('when rendered then the copy and dismiss hints are shown', () {
      expect(line, contains('copy'));
      expect(line, contains('close'));
    });
  });
}
