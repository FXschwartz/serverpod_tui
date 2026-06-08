import 'dart:async';

import 'package:meta/meta.dart';
import 'package:nocterm/nocterm.dart';
import 'package:serverpod_tui/src/alert_message.dart';
import 'package:serverpod_tui/src/app_state_holder.dart';
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
      ClipboardManager.copy(state.selectedText);
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
      ClipboardManager.copy(text);
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          Text(
            '! ',
            style: TextStyle(
              color: st.warningLevel,
              fontWeight: FontWeight.bold,
            ),
          ),
          Flexible(
            child: Text(
              alert.displayText,
              style: TextStyle(
                color: st.brightText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (alert.copyText != null) ...[
            Text(
              ' (copied to clipboard)',
              style: TextStyle(color: st.subtleDivider),
            ),
            const Text('  '),
            Text(
              'C',
              style: TextStyle(
                color: st.activationKey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(' Copy · '),
          ] else
            const Text('  '),
          Text(
            'Esc',
            style: TextStyle(
              color: st.activationKey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(' Dismiss'),
        ],
      ),
    );
  }
}
