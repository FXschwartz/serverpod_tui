import 'dart:async';

import 'package:meta/meta.dart';
import 'package:nocterm/nocterm.dart';
import 'package:serverpod_tui/src/alert_message.dart';
import 'package:serverpod_tui/src/app_state_holder.dart';
import 'package:serverpod_tui/src/clipboard.dart';
import 'package:serverpod_tui/src/components/spinner.dart';
import 'package:serverpod_tui/src/run_app.dart';
import 'package:serverpod_tui/src/serverpod_theme.dart';

/// A root TUI component.
abstract class TuiApp<T extends TuiAppStateHolder> extends StatefulComponent {
  const TuiApp({super.key, required this.holder});

  final T holder;

  @override
  TuiAppState<TuiApp> createState();
}

/// The logic and internal state for a [TuiApp].
abstract class TuiAppState<S extends TuiApp> extends State<S> {
  /// How long after a first Ctrl-C a second press still counts as "exit".
  static const _exitArmWindow = Duration(seconds: 2);

  bool _exitArmed = false;
  Timer? _exitArmTimer;
  Timer? _hintClearTimer;

  @override
  void initState() {
    super.initState();
    component.holder.attach(this);
  }

  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;
    super.setState(fn);
  }

  @override
  void dispose() {
    _exitArmTimer?.cancel();
    _hintClearTimer?.cancel();
    component.holder.detach(this);
    super.dispose();
  }

  void rebuild() {
    setState(() {});
  }

  /// Called when a second Ctrl-C confirms exit.
  ///
  /// The default performs a graceful shutdown via [shutdownTuiApp], which runs
  /// the terminal backend's exit hook. Override to run app-specific teardown
  /// (e.g. stopping a server or Docker) before the app exits.
  @protected
  void onExit() => shutdownTuiApp();

  /// Handles Ctrl-C: copies the current selection if there is one, otherwise
  /// the first press arms exit and shows a hint and a second press within
  /// [_exitArmWindow] calls [onExit].
  ///
  /// Returns true for Ctrl-C so nocterm's signal handler never falls back to
  /// its abrupt default shutdown, which would bypass [onExit].
  bool _handleCtrlC(KeyboardEvent event) {
    if (event.logicalKey != LogicalKey.keyC || !event.isControlPressed) {
      return false;
    }

    final state = component.holder.state;

    if (state.selectedText.isNotEmpty) {
      copyToClipboard(state.selectedText);
      // Consume the selection so the next Ctrl-C arms exit. The visual
      // highlight is dropped when the log views re-render (e.g. the hint
      // line shifts layout), so keeping the text would let later Ctrl-C
      // presses silently re-copy a selection that is no longer on screen.
      state.selectedText = '';
      _disarmExit();
      _showHint('Copied to clipboard', autoClear: true);
      return true;
    }

    if (_exitArmed) {
      _disarmExit();
      onExit();
      return true;
    }

    _exitArmed = true;
    _showHint('Press Ctrl-C again to exit', autoClear: false);
    _exitArmTimer?.cancel();
    _exitArmTimer = Timer(_exitArmWindow, () {
      _exitArmed = false;
      _clearHint();
    });
    return true;
  }

  void _showHint(String message, {required bool autoClear}) {
    component.holder.state.ctrlCHint = message;
    _hintClearTimer?.cancel();
    if (autoClear) _hintClearTimer = Timer(_exitArmWindow, _clearHint);
    rebuild();
  }

  void _clearHint() {
    component.holder.state.ctrlCHint = null;
    rebuild();
  }

  void _disarmExit() {
    _exitArmed = false;
    _exitArmTimer?.cancel();
  }

  void dismissAlert() {
    component.holder.state.alert = null;
    rebuild();
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (_handleCtrlC(event)) return true;
    return _handleAlertKeys(event);
  }

  // Escape dismisses the alert; C re-copies its segment in case the clipboard
  // has been overwritten since the alert appeared.
  bool _handleAlertKeys(KeyboardEvent event) {
    final alert = component.holder.state.alert;
    if (alert == null) return false;

    if (event.matches(LogicalKey.escape)) {
      dismissAlert();
      return true;
    }

    if (alert.copyText case final text?
        when event.logicalKey == LogicalKey.keyC &&
            !event.isControlPressed &&
            !event.isAltPressed &&
            !event.isMetaPressed) {
      copyToClipboard(text);
      _showHint('Copied to clipboard', autoClear: true);
      return true;
    }

    return false;
  }

  /// Describes the part of the user interface represented by this component.
  Component buildApp(BuildContext context);

  @override
  @protected
  Component build(BuildContext context) {
    final state = component.holder.state;

    return NoctermApp(
      child: Builder(
        builder: (context) {
          final themeData = TuiTheme.of(context);
          return TuiTheme(
            data: themeData.copyWith(
              background: Color.defaultColor,
            ),
            child: SpinnerScope(
              active: state.activeOperations.isNotEmpty,
              // Ctrl-C and the alert keys (Escape, C) are routed here as
              // keyboard events. The app's own key handlers run first
              // (depth-first dispatch); only unhandled keys bubble up to
              // this Focusable.
              child: Focusable(
                focused: true,
                onKeyEvent: _handleKeyEvent,
                child: _withMessageBar(context, buildApp(context)),
              ),
            ),
          );
        },
      ),
    );
  }

  // The transient hint and the pinned alert share the bottom line; the hint
  // wins while it's visible.
  Component _withMessageBar(BuildContext context, Component child) {
    final state = component.holder.state;
    final hint = state.ctrlCHint;
    final alert = state.alert;
    final st = ServerpodTheme.of(context);

    // Always wrap in the same Column, only toggling the message row. Returning
    // the bare child when there is no message would change the component type
    // in this slot, remounting the entire app subtree (and losing all of its
    // state: scroll positions, selections, splash fade progress) every time
    // the message appears or disappears.
    return Column(
      children: [
        Expanded(child: child),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              hint,
              style: TextStyle(
                color: st.brightText,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else if (alert != null)
          _buildAlertLine(st, alert),
      ],
    );
  }

  Component _buildAlertLine(ServerpodThemeData st, AlertMessage alert) {
    // nocterm's Text has no ellipsis/clip, so a line wider than the terminal
    // wraps and steals rows from the app above. Measure the width and build a
    // single pre-truncated line instead.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth.floor()
              : alert.displayText.length + 32;
          // Centered when it fits; pre-truncated to fill the width otherwise.
          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _alertSpans(st, alert, maxWidth),
            ),
          );
        },
      ),
    );
  }

  /// Builds the alert line's spans, fitted to [maxWidth] columns. The message
  /// is truncated from the left so the trailing code stays visible, and the
  /// code (if any) is emphasised.
  List<Component> _alertSpans(
    ServerpodThemeData st,
    AlertMessage alert,
    int maxWidth,
  ) {
    const prefix = '! ';
    final code = alert.copyText;

    // (text, isKey) pairs for the trailing action hints.
    final hints = <(String, bool)>[
      (' · ', false),
      if (code != null) ...[('C', true), (' copy ', false)],
      ('Esc', true),
      (' close', false),
    ];
    final hintsWidth = hints.fold<int>(0, (w, h) => w + h.$1.length);

    final available = maxWidth - prefix.length - hintsWidth;
    final message = _truncateKeepingTail(alert.displayText, available);

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
              style: TextStyle(
                color: st.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            plain(message.substring(codeStart + code.length)),
          ];

    return [
      Text(
        prefix,
        style: TextStyle(color: st.warningLevel, fontWeight: FontWeight.bold),
      ),
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
