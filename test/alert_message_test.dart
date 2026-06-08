import 'package:serverpod_tui/src/alert_message.dart';
import 'package:test/test.dart';

void main() {
  group('Given a message without copy markup', () {
    late AlertMessage alert;

    setUp(() {
      alert = AlertMessage.parse('Server started on port 8080');
    });

    test('when parsed then the text is kept verbatim', () {
      expect(alert.displayText, 'Server started on port 8080');
    });

    test('when parsed then there is no copy text', () {
      expect(alert.copyText, isNull);
    });
  });

  group('Given a message with a marked segment', () {
    late AlertMessage alert;

    setUp(() {
      alert = AlertMessage.parse('Registration code: <h2k9x3mp>');
    });

    test('when parsed then the brackets are stripped for display', () {
      expect(alert.displayText, 'Registration code: h2k9x3mp');
    });

    test('when parsed then the marked segment becomes the copy text', () {
      expect(alert.copyText, 'h2k9x3mp');
    });
  });

  group('Given a message with a marked segment mid-text', () {
    late AlertMessage alert;

    setUp(() {
      alert = AlertMessage.parse('Use code <123456> to verify');
    });

    test('when parsed then the surrounding text is preserved', () {
      expect(alert.displayText, 'Use code 123456 to verify');
    });

    test('when parsed then the marked segment becomes the copy text', () {
      expect(alert.copyText, '123456');
    });
  });

  group('Given a message with multiple marked segments', () {
    late AlertMessage alert;

    setUp(() {
      alert = AlertMessage.parse('Code <123> or backup <456>');
    });

    test('when parsed then only the first segment becomes the copy text', () {
      expect(alert.copyText, '123');
    });

    test('when parsed then later segments are left verbatim', () {
      expect(alert.displayText, 'Code 123 or backup <456>');
    });
  });

  group('Given a message with empty brackets', () {
    late AlertMessage alert;

    setUp(() {
      alert = AlertMessage.parse('Empty <> brackets');
    });

    test('when parsed then they are not treated as copy markup', () {
      expect(alert.displayText, 'Empty <> brackets');
      expect(alert.copyText, isNull);
    });
  });

  group('Given a message with an unclosed bracket', () {
    late AlertMessage alert;

    setUp(() {
      alert = AlertMessage.parse('Compare a < b');
    });

    test('when parsed then it is not treated as copy markup', () {
      expect(alert.displayText, 'Compare a < b');
      expect(alert.copyText, isNull);
    });
  });
}
