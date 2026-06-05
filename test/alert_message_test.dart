import 'package:serverpod_tui/src/alert_message.dart';
import 'package:test/test.dart';

void main() {
  group('Given a message without copy markup', () {
    test('when parsed then the text is kept verbatim with no copy text', () {
      final alert = AlertMessage.parse('Server started on port 8080');

      expect(alert.displayText, 'Server started on port 8080');
      expect(alert.copyText, isNull);
    });
  });

  group('Given a message with a marked segment', () {
    test('when parsed then the brackets are stripped for display', () {
      final alert = AlertMessage.parse('Registration code: <h2k9x3mp>');

      expect(alert.displayText, 'Registration code: h2k9x3mp');
    });

    test('when parsed then the marked segment becomes the copy text', () {
      final alert = AlertMessage.parse('Registration code: <h2k9x3mp>');

      expect(alert.copyText, 'h2k9x3mp');
    });

    test('when parsed then text after the marked segment is preserved', () {
      final alert = AlertMessage.parse('Use code <123456> to verify');

      expect(alert.displayText, 'Use code 123456 to verify');
      expect(alert.copyText, '123456');
    });
  });

  group('Given a message with multiple marked segments', () {
    test(
      'when parsed then only the first is treated as copyable '
      'and the rest are left verbatim',
      () {
        final alert = AlertMessage.parse('Code <123> or backup <456>');

        expect(alert.displayText, 'Code 123 or backup <456>');
        expect(alert.copyText, '123');
      },
    );
  });

  group('Given a message with empty brackets', () {
    test('when parsed then they are not treated as copy markup', () {
      final alert = AlertMessage.parse('Empty <> brackets');

      expect(alert.displayText, 'Empty <> brackets');
      expect(alert.copyText, isNull);
    });
  });

  group('Given a message with an unclosed bracket', () {
    test('when parsed then it is not treated as copy markup', () {
      final alert = AlertMessage.parse('Compare a < b');

      expect(alert.displayText, 'Compare a < b');
      expect(alert.copyText, isNull);
    });
  });
}
