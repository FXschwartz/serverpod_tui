import 'package:nocterm/nocterm.dart' hide isEmpty;
import 'package:serverpod_tui/serverpod_tui.dart';
import 'package:test/test.dart';

import 'util.dart';

Future<void> _sendKey(NoctermTester tester, LogicalKey key) {
  return tester.sendKeyEvent(KeyboardEvent(logicalKey: key));
}

// Waits past the holder's 80ms rebuild throttle so the trailing frame lands.
Future<void> _pump(NoctermTester tester) {
  return tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late NoctermTester tester;
  late TestState state;
  late TestStateHolder holder;

  setUp(() async {
    state = TestState();
    holder = TestStateHolder(state);
    tester = await NoctermTester.create(size: const Size(80, 24));
    await tester.pumpComponent(TestApp(holder: holder));
  });

  tearDown(() async {
    tester.dispose();
    await holder.dispose();
  });

  group('Given an alert with a copyable segment', () {
    setUp(() async {
      holder.showAlert(AlertMessage.parse('Registration code: <h2k9x3mp>'));
      await _pump(tester);
    });

    test('when shown then it becomes the current alert', () {
      expect(state.alert?.displayText, 'Registration code: h2k9x3mp');
      expect(state.alert?.copyText, 'h2k9x3mp');
    });

    test('when shown then the segment is auto-copied to the clipboard', () {
      expect(ClipboardManager.paste(), 'h2k9x3mp');
    });

    test('when Escape is pressed then the alert is dismissed', () async {
      await _sendKey(tester, LogicalKey.escape);

      expect(state.alert, isNull);
    });

    test('when a newer alert is shown then it replaces the previous one', () {
      holder.showAlert(AlertMessage.parse('Password reset code: <z7q1w8rt>'));

      expect(state.alert?.copyText, 'z7q1w8rt');
      expect(ClipboardManager.paste(), 'z7q1w8rt');
    });

    group('and the clipboard has since been overwritten', () {
      setUp(() {
        ClipboardManager.copy('something else');
      });

      test('when C is pressed then the segment is copied again', () async {
        await _sendKey(tester, LogicalKey.keyC);

        expect(ClipboardManager.paste(), 'h2k9x3mp');
      });

      test('when C is pressed then a confirmation hint is shown', () async {
        await _sendKey(tester, LogicalKey.keyC);

        expect(state.ctrlCHint, 'Copied to clipboard');
      });
    });
  });

  group('Given an alert without a copyable segment', () {
    setUp(() async {
      ClipboardManager.copy('previous clipboard content');
      holder.showAlert(AlertMessage.parse('Server requires a restart'));
      await _pump(tester);
    });

    test('when shown then the clipboard is left untouched', () {
      expect(ClipboardManager.paste(), 'previous clipboard content');
    });

    test(
      'when C is pressed then nothing is copied and no hint appears',
      () async {
        await _sendKey(tester, LogicalKey.keyC);

        expect(ClipboardManager.paste(), 'previous clipboard content');
        expect(state.ctrlCHint, isNull);
      },
    );

    test('when Escape is pressed then the alert is dismissed', () async {
      await _sendKey(tester, LogicalKey.escape);

      expect(state.alert, isNull);
    });
  });

  group('Given no alert', () {
    test('when Escape is pressed then the state is unchanged', () async {
      await _sendKey(tester, LogicalKey.escape);

      expect(state.alert, isNull);
      expect(state.ctrlCHint, isNull);
    });
  });
}
