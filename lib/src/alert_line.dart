import 'package:intl/intl.dart';
import 'package:nocterm/nocterm.dart';
import 'package:serverpod_tui/src/alert_message.dart';
import 'package:serverpod_tui/src/serverpod_theme.dart';

final _timeFormat = DateFormat('HH:mm:ss.SSS');

/// Renders an [AlertMessage] as a pinned, log-styled line: an `alert` marker
/// and timestamp aligned with the log entries' level/time columns, followed by
/// the message (with its code emphasised) and `C copy` / `Esc close` hints.
///
/// The message is left-truncated (keeping the trailing code) when it doesn't
/// fit, so the line never wraps. Place it where it should appear - e.g. pinned
/// at the bottom of a log panel.
class AlertLine extends StatelessComponent {
  const AlertLine({super.key, required this.alert, this.time});

  final AlertMessage alert;

  /// When the alert was raised; rendered in the same column as log timestamps.
  /// Omitted when null.
  final DateTime? time;

  @override
  Component build(BuildContext context) {
    final st = ServerpodTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 'alert' is five characters, matching the log level labels so the
        // timestamp lines up with the log entries' time column.
        Text(
          'alert',
          style: TextStyle(color: st.warningLevel, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 1),
        if (time case final time?) ...[
          Text(
            _timeFormat.format(time.toLocal()),
            style: const TextStyle(fontWeight: FontWeight.dim),
          ),
          const SizedBox(width: 1),
        ],
        // nocterm's Text has no ellipsis/clip, so a line wider than its
        // container wraps. Measure the remaining width and pre-truncate.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth.floor()
                  : alert.displayText.length + 20;
              return Row(children: _messageSpans(st, maxWidth));
            },
          ),
        ),
      ],
    );
  }

  /// Builds the message and hint spans, fitted to [maxWidth] columns. The
  /// message is truncated from the left so the trailing code stays visible,
  /// and the code (if any) is emphasised.
  List<Component> _messageSpans(ServerpodThemeData st, int maxWidth) {
    final code = alert.copyText;

    // (text, isKey) pairs for the trailing action hints. The keys are
    // bracketed so they read as prominent keycaps.
    final hints = <(String, bool)>[
      (' · ', false),
      if (code != null) ...[('[C]', true), (' copy ', false)],
      ('[Esc]', true),
      (' dismiss', false),
    ];
    final hintsWidth = hints.fold<int>(0, (w, h) => w + h.$1.length);

    final message = _truncateKeepingTail(
      alert.displayText,
      maxWidth - hintsWidth,
    );

    Text plain(String text) =>
        Text(text, style: TextStyle(color: st.brightText));

    // Emphasise the code where it survives in the (possibly truncated) message.
    final codeStart = code == null ? -1 : message.lastIndexOf(code);
    final messageSpans = codeStart < 0
        ? [plain(message)]
        : [
            plain(message.substring(0, codeStart)),
            Text(
              code!,
              style: TextStyle(color: st.primary, fontWeight: FontWeight.bold),
            ),
            plain(message.substring(codeStart + code.length)),
          ];

    return [
      ...messageSpans,
      for (final (text, isKey) in hints)
        Text(
          text,
          style: TextStyle(
            color: isKey ? st.activationKey : st.subtleDivider,
            fontWeight: isKey ? FontWeight.bold : FontWeight.normal,
          ),
        ),
    ];
  }

  /// Truncates [text] to [width] columns, keeping the tail and prefixing an
  /// ellipsis when it doesn't fit. Returns empty when there is no room.
  static String _truncateKeepingTail(String text, int width) {
    if (width <= 0) return '';
    if (text.length <= width) return text;
    if (width == 1) return '…';
    return '…${text.substring(text.length - (width - 1))}';
  }
}
