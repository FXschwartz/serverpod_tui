import 'package:nocterm/nocterm.dart';
import 'package:serverpod_tui/src/app.dart';
import 'package:serverpod_tui/src/app_state_holder.dart';
import 'package:serverpod_tui/src/bounded_queue_list.dart';
import 'package:serverpod_tui/src/state.dart';

class TestState extends TuiState {
  @override
  final logHistory = BoundedQueueList<Object>(maxLogEntries);

  @override
  final rawLines = BoundedQueueList<String>(maxRawLines);

  @override
  final Map<String, TrackedOperation> activeOperations = {};

  /// Maximum number of log entries to keep.
  static const maxLogEntries = 10000;

  /// Maximum number of raw lines to keep.
  static const maxRawLines = 10000;
}

class TestStateHolder extends TuiAppStateHolder<TestState> {
  TestStateHolder(this._state);

  final TestState _state;
  TuiAppState? _widgetState;

  @override
  void attach(TuiAppState widgetState) => _widgetState = widgetState;

  @override
  void detach(TuiAppState widgetState) {
    if (_widgetState == widgetState) _widgetState = null;
  }

  @override
  TestState get state => _state;

  @override
  TuiAppState? get widgetState => _widgetState;
}

/// A minimal [TuiApp] for exercising base [TuiAppState] behavior in tests.
///
/// [onExitCallback] stands in for app-specific teardown so a confirming Ctrl-C
/// is observable without actually shutting the process down.
class TestApp extends TuiApp<TestStateHolder> {
  const TestApp({super.key, required super.holder, this.onExitCallback});

  final void Function()? onExitCallback;

  @override
  TuiAppState<TuiApp> createState() => TestAppState();
}

class TestAppState extends TuiAppState<TestApp> {
  @override
  void onExit() => component.onExitCallback?.call();

  @override
  Component buildApp(BuildContext context) => const SizedBox();
}
