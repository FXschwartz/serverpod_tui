/// A message surfaced prominently at the bottom of the TUI until dismissed,
/// e.g. an email verification code logged by the server.
///
/// The raw message may mark a copyable segment with angle brackets:
/// `Verification: <123456>` is displayed as `Verification: 123456` with
/// `123456` available as [copyText].
final class AlertMessage {
  const AlertMessage._({required this.displayText, this.copyText});

  /// The message with any copy markup stripped.
  final String displayText;

  /// The segment marked as copyable in the raw message, or null if the
  /// message contained no markup.
  final String? copyText;

  /// The first `<...>` pair, captured without the brackets. Nested or empty
  /// brackets are not treated as markup.
  static final _copyMarkup = RegExp(r'<([^<>]+)>');

  /// Parses [raw], extracting an optional copyable segment marked with
  /// angle brackets. Only the first marked segment is treated as copyable;
  /// any further markup is left verbatim.
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
