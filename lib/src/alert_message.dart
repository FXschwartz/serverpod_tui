/// A message pinned to the bottom of the TUI until dismissed, e.g. an email
/// verification code logged by the server.
///
/// A copyable segment can be marked with angle brackets: `Code: <123456>` is
/// displayed as `Code: 123456`, with `123456` exposed as [copyText].
final class AlertMessage {
  const AlertMessage._({required this.displayText, this.copyText});

  /// The message with any copy markup stripped.
  final String displayText;

  /// The copyable segment, or null if the message contained no markup.
  final String? copyText;

  // Matches the first `<...>` pair. Excluding `<>` from the inner group means
  // empty and unclosed brackets fall through as plain text.
  static final _copyMarkup = RegExp(r'<([^<>]+)>');

  /// Parses [raw]. Only the first marked segment is treated as copyable; any
  /// later markup is left verbatim.
  factory AlertMessage.parse(String raw) {
    final match = _copyMarkup.firstMatch(raw);
    if (match == null) {
      return AlertMessage._(displayText: raw);
    }
    return AlertMessage._(
      displayText: raw.replaceRange(match.start, match.end, match[1]!),
      copyText: match[1],
    );
  }
}
