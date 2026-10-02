import 'package:nocterm/nocterm.dart' hide isEmpty;
import 'package:serverpod_tui/serverpod_tui.dart';
import 'package:test/test.dart';

import '../util.dart';

// --- Test configs ---

enum DatabaseOption implements FormConfigOption {
  postgres('Postgres'),
  sqlite('SQLite')
  ;

  const DatabaseOption(this.label);
  @override
  final String label;
}

enum SimpleConfig<T extends FormConfigOption>
    implements FormSelectionConfig<T> {
  database<DatabaseOption>(
    label: 'Database',
    options: DatabaseOption.values,
    defaultOptions: {DatabaseOption.postgres},
  ),
  auth<BoolFormConfigOption>(
    label: 'Authentication',
    options: BoolFormConfigOption.values,
    defaultOptions: {BoolFormConfigOption.enabled},
  )
  ;

  const SimpleConfig({
    required this.label,
    required this.options,
    required this.defaultOptions,
    this.requirements = const [],
    this.multiSelect = false,
    this.exclusiveOptions = const {},
    this.selectionRequired = false,
    this.description,
  });

  @override
  final String label;
  @override
  final List<T> options;
  @override
  final Set<T> defaultOptions;
  @override
  final List<FormRequirement> requirements;
  @override
  final bool multiSelect;
  @override
  final Set<T> exclusiveOptions;
  @override
  final bool selectionRequired;
  @override
  final FormDescription? description;
}

enum EditorOption implements FormConfigOption {
  vsCode('VS Code'),
  cursor('Cursor')
  ;

  const EditorOption(this.label);
  @override
  final String label;
}

class RequiredEditorConfig implements FormSelectionConfig<EditorOption> {
  const RequiredEditorConfig();

  @override
  String get label => 'Editors';
  @override
  List<EditorOption> get options => EditorOption.values;
  @override
  Set<EditorOption> get defaultOptions => const {};
  @override
  bool get multiSelect => true;
  @override
  bool get selectionRequired => true;
  @override
  Set<EditorOption> get exclusiveOptions => const {};
  @override
  List<FormRequirement> get requirements => const [];
  @override
  FormDescription? get description => null;
}

// --- Test app infrastructure ---

class _MultiScreenTestState extends TuiState {
  _MultiScreenTestState(this.formState);

  final MultiScreenFormState formState;

  @override
  final logHistory = BoundedQueueList<Object>(TestState.maxLogEntries);

  @override
  final Map<String, TrackedOperation> activeOperations = {};
}

class _MultiScreenTestHolder extends TuiAppStateHolder<_MultiScreenTestState> {
  _MultiScreenTestHolder(this._state);

  final _MultiScreenTestState _state;
  TuiAppState? _widgetState;

  @override
  _MultiScreenTestState get state => _state;

  @override
  TuiAppState? get widgetState => _widgetState;

  @override
  void attach(TuiAppState widgetState) {
    _widgetState = widgetState;
  }

  @override
  void detach(TuiAppState widgetState) {
    if (_widgetState == widgetState) _widgetState = null;
  }
}

class _MultiScreenTestApp extends TuiApp<_MultiScreenTestHolder> {
  const _MultiScreenTestApp({
    required super.holder,
    this.submitButtonLabel,
    this.onSubmit,
  });

  final String? submitButtonLabel;
  final VoidCallback? onSubmit;

  @override
  TuiAppState<_MultiScreenTestApp> createState() => _MultiScreenTestAppState();
}

class _MultiScreenTestAppState extends TuiAppState<_MultiScreenTestApp> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Component buildApp(BuildContext context) {
    final formState = component.holder.state.formState;

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.isControlPressed ||
            event.isAltPressed ||
            event.isMetaPressed) {
          return false;
        }
        switch (event.logicalKey) {
          case LogicalKey.enter:
            if (formState.isSummary) {
              return false;
            }
            formState.nextScreen();
            component.holder.markDirty();
            return true;
          case LogicalKey.escape:
            formState.previousScreen();
            component.holder.markDirty();
            return true;
          case LogicalKey.arrowDown:
            formState.focusDown();
            component.holder.markDirty();
            return true;
          case LogicalKey.space:
            if (formState.focusOnButton && formState.focusedButtonIndex == 1) {
              return false;
            }
            formState.onSelect();
            component.holder.markDirty();
            return true;
          case LogicalKey.arrowLeft:
            formState.focusLeft();
            component.holder.markDirty();
            return true;
          case LogicalKey.arrowRight:
            formState.focusRight();
            component.holder.markDirty();
            return true;
        }
        return false;
      },
      child: Form.multiScreen(
        state: formState,
        scrollController: _scrollController,
        rebuild: component.holder.markDirty,
        submitButtonLabel: component.submitButtonLabel,
        onSubmit: component.onSubmit,
      ),
    );
  }
}

// --- Helpers ---

Future<void> _sendKey(NoctermTester tester, LogicalKey key) {
  return tester.sendKeyEvent(KeyboardEvent(logicalKey: key));
}

Future<void> _pump(NoctermTester tester) {
  return tester.pump(const Duration(milliseconds: 100));
}

// --- Tests ---

void main() {
  group('Given a multi-screen form with multiple configs', () {
    late NoctermTester tester;
    late MultiScreenFormState state;
    late _MultiScreenTestHolder holder;

    setUp(() async {
      state = MultiScreenFormState(SimpleConfig.values);
      holder = _MultiScreenTestHolder(_MultiScreenTestState(state));
      tester = await NoctermTester.create(size: const Size(80, 24));
      await tester.pumpComponent(
        _MultiScreenTestApp(holder: holder),
      );
    });

    tearDown(() async {
      tester.dispose();
      await holder.dispose();
    });

    test(
      'when Enter is pressed on the first screen, '
      'then it advances to the next screen',
      () async {
        expect(state.currentScreenIndex, 0);

        await _sendKey(tester, LogicalKey.enter);
        await _pump(tester);

        expect(state.currentScreenIndex, 1);
      },
    );

    test(
      'when on the first screen, '
      'then only the Next button is shown',
      () async {
        await _pump(tester);

        final screenText = tester.terminalState.getText();
        expect(screenText, isNot(contains('Back')));
        expect(screenText, contains('Next'));
      },
    );

    test(
      'when on non-first screen, '
      'then the Back and Next buttons are shown',
      () async {
        await _pump(tester);

        await _sendKey(tester, LogicalKey.enter);
        await _pump(tester);

        final screenText = tester.terminalState.getText();
        expect(screenText, contains('Back'));
        expect(screenText, contains('Next'));
      },
    );

    test(
      'when Escape is pressed on the first screen, '
      'then it stays on the first screen',
      () async {
        expect(state.currentScreenIndex, 0);

        await _sendKey(tester, LogicalKey.escape);
        await _pump(tester);

        expect(state.currentScreenIndex, 0);
      },
    );

    test(
      'when Escape is pressed on a non-first screen, '
      'then it goes back to the previous screen',
      () async {
        await _sendKey(tester, LogicalKey.enter);
        await _pump(tester);
        expect(state.currentScreenIndex, 1);

        await _sendKey(tester, LogicalKey.escape);
        await _pump(tester);

        expect(state.currentScreenIndex, 0);
      },
    );

    test(
      'when buttons are activated using arrowDown on the first screen, '
      'and the Next button is activated using Space key, '
      'then it advances to the next screen',
      () async {
        await _pump(tester);
        expect(state.currentScreenIndex, 0);

        // Focus on Next button.
        // Back button is disabled on the first screen
        await _sendKey(tester, LogicalKey.arrowDown);
        await _pump(tester);
        expect(state.focusOnButton, isTrue);
        expect(state.focusedButtonIndex, 1);

        // Space to press Next button
        await _sendKey(tester, LogicalKey.space);
        await _pump(tester);

        expect(state.currentScreenIndex, 1);
      },
    );

    test(
      'when buttons are activated using arrowDown on a non-first screen, '
      'and the Back button is activated using Space key, '
      'then it goes back to the previous screen',
      () async {
        await _sendKey(tester, LogicalKey.enter);
        await _pump(tester);
        expect(state.currentScreenIndex, 1);

        // Focus on buttons. Back button is focused
        await _sendKey(tester, LogicalKey.arrowDown);
        await _pump(tester);
        expect(state.focusOnButton, isTrue);
        expect(state.focusedButtonIndex, 0);

        // Space to press back button
        await _sendKey(tester, LogicalKey.space);
        await _pump(tester);

        expect(state.currentScreenIndex, 0);
      },
    );

    test(
      'when navigating through all screens, '
      'then the summary screen is reached and the Next button is focused',
      () async {
        final configCount = state.configScreenCount;

        for (var i = 0; i < configCount; i++) {
          expect(state.isSummary, isFalse);
          expect(state.currentScreenIndex, i);
          await _sendKey(tester, LogicalKey.enter);
          await _pump(tester);
        }

        expect(state.isSummary, isTrue);
        expect(state.currentScreenIndex, configCount);
        expect(state.focusedButtonIndex, 1);
      },
    );

    test(
      'when navigating through all screens until the summary and pressing Space on the Back button, '
      'then it goes back to the previous screen',
      () async {
        for (var i = 0; i < state.configScreenCount; i++) {
          await _sendKey(tester, LogicalKey.enter);
          await _pump(tester);
        }
        expect(state.currentScreenIndex, state.configScreenCount);
        expect(state.isSummary, isTrue);

        // Focus on buttons
        await _sendKey(tester, LogicalKey.arrowDown);
        await _sendKey(tester, LogicalKey.arrowLeft);
        await _pump(tester);

        // Space to press back button
        await _sendKey(tester, LogicalKey.space);
        await _pump(tester);

        expect(state.currentScreenIndex, state.configScreenCount - 1);
        expect(state.isSummary, isFalse);
      },
    );

    test(
      'when on the summary screen and no submitButtonLabel is provided, '
      'then the action button shows "Submit"',
      () async {
        for (var i = 0; i < state.configScreenCount; i++) {
          await _sendKey(tester, LogicalKey.enter);
          await _pump(tester);
        }
        expect(state.isSummary, isTrue);

        final screenText = tester.terminalState.getText();
        expect(screenText, contains('Submit'));
      },
    );
  });

  group('Given a multi-screen form with a single config', () {
    late NoctermTester tester;
    late MultiScreenFormState state;
    late _MultiScreenTestHolder holder;

    setUp(() async {
      state = MultiScreenFormState([SimpleConfig.database]);
      holder = _MultiScreenTestHolder(_MultiScreenTestState(state));
      tester = await NoctermTester.create(size: const Size(80, 24));
      await tester.pumpComponent(
        _MultiScreenTestApp(holder: holder),
      );
    });

    tearDown(() async {
      tester.dispose();
      await holder.dispose();
    });

    test('then hasSingleScreen is true', () {
      expect(state.hasSingleScreen, isTrue);
    });

    test(
      'when arrowDown is pressed, '
      'then the Submit button is shown and focused',
      () async {
        await _sendKey(tester, LogicalKey.arrowDown);
        await _pump(tester);

        final screenText = tester.terminalState.getText();
        expect(screenText, isNot(contains('Back')));
        expect(screenText, contains('Submit'));

        expect(state.focusOnButton, isTrue);
        expect(state.currentScreenIndex, 0);
      },
    );

    test(
      'when Enter is pressed, '
      'then the screen index does not change',
      () async {
        await _sendKey(tester, LogicalKey.enter);
        await _pump(tester);

        expect(state.currentScreenIndex, 0);
        expect(state.isSummary, isFalse);
      },
    );

    test(
      'when escape is pressed, '
      'then the screen index does not change',
      () async {
        await _sendKey(tester, LogicalKey.escape);
        await _pump(tester);

        expect(state.currentScreenIndex, 0);
        expect(state.isSummary, isFalse);
      },
    );
  });

  group('Given a multi-screen form with a custom submitButtonLabel', () {
    late NoctermTester tester;
    late MultiScreenFormState state;
    late _MultiScreenTestHolder holder;

    setUp(() async {
      state = MultiScreenFormState(SimpleConfig.values);
      holder = _MultiScreenTestHolder(_MultiScreenTestState(state));
      tester = await NoctermTester.create(size: const Size(80, 24));
      await tester.pumpComponent(
        _MultiScreenTestApp(holder: holder, submitButtonLabel: 'Create'),
      );
    });

    tearDown(() async {
      tester.dispose();
      await holder.dispose();
    });

    test(
      'when on the summary screen, '
      'then the action button shows the custom label',
      () async {
        for (var i = 0; i < state.configScreenCount; i++) {
          await _sendKey(tester, LogicalKey.enter);
          await _pump(tester);
        }
        expect(state.isSummary, isTrue);

        final screenText = tester.terminalState.getText();
        expect(screenText, contains('Create'));
      },
    );
  });

  group('Given a multi-screen form with multiple configs and onSubmit', () {
    late NoctermTester tester;
    late MultiScreenFormState state;
    late _MultiScreenTestHolder holder;
    var onSubmitCalled = false;

    setUp(() async {
      onSubmitCalled = false;
      state = MultiScreenFormState(SimpleConfig.values);
      holder = _MultiScreenTestHolder(_MultiScreenTestState(state));
      tester = await NoctermTester.create(size: const Size(80, 24));
      await tester.pumpComponent(
        _MultiScreenTestApp(
          holder: holder,
          onSubmit: () => onSubmitCalled = true,
        ),
      );
    });

    tearDown(() async {
      tester.dispose();
      await holder.dispose();
    });

    test(
      'when on the summary screen and Space activates the submit button, '
      'then onSubmit is called',
      () async {
        // Navigate to summary
        for (var i = 0; i < state.configScreenCount; i++) {
          await _sendKey(tester, LogicalKey.enter);
          await _pump(tester);
        }
        expect(state.isSummary, isTrue);
        expect(onSubmitCalled, isFalse);

        // Focus on Back button, then move to submit button
        await _sendKey(tester, LogicalKey.arrowDown);
        await _pump(tester);
        await _sendKey(tester, LogicalKey.arrowRight);
        await _pump(tester);
        expect(state.focusOnButton, isTrue);
        expect(state.focusedButtonIndex, 1);
        expect(onSubmitCalled, isFalse);

        // Space to activate the submit button
        await _sendKey(tester, LogicalKey.space);
        await _pump(tester);

        expect(onSubmitCalled, isTrue);
      },
    );
  });

  group('Given a multi-screen form with a single config and onSubmit', () {
    late NoctermTester tester;
    late MultiScreenFormState state;
    late _MultiScreenTestHolder holder;
    var onSubmitCalled = false;

    setUp(() async {
      onSubmitCalled = false;
      state = MultiScreenFormState([SimpleConfig.database]);
      holder = _MultiScreenTestHolder(_MultiScreenTestState(state));
      tester = await NoctermTester.create(size: const Size(80, 24));
      await tester.pumpComponent(
        _MultiScreenTestApp(
          holder: holder,
          onSubmit: () => onSubmitCalled = true,
        ),
      );
    });

    tearDown(() async {
      tester.dispose();
      await holder.dispose();
    });

    test(
      'when on the first screen and Space activates the submit button, '
      'then onSubmit is called',
      () async {
        // Navigate to the summary screen (hasSingleScreen: Enter does nothing,
        // but we use arrowDown to focus the submit button)
        await _sendKey(tester, LogicalKey.arrowDown);
        await _pump(tester);
        expect(state.focusOnButton, isTrue);
        expect(state.focusedButtonIndex, 1);
        expect(state.currentScreenIndex, 0);
        expect(onSubmitCalled, isFalse);

        // Space to activate the submit button via the outer handler
        await _sendKey(tester, LogicalKey.space);
        await _pump(tester);

        expect(onSubmitCalled, isTrue);
      },
    );
  });

  group(
    'Given a multi-screen form whose first config requires a selection',
    () {
      late NoctermTester tester;
      late MultiScreenFormState state;
      late _MultiScreenTestHolder holder;

      setUp(() async {
        state = MultiScreenFormState([
          const RequiredEditorConfig(),
          SimpleConfig.database,
        ]);
        holder = _MultiScreenTestHolder(_MultiScreenTestState(state));
        tester = await NoctermTester.create(size: const Size(80, 24));
        await tester.pumpComponent(
          _MultiScreenTestApp(holder: holder),
        );
      });

      tearDown(() async {
        tester.dispose();
        await holder.dispose();
      });

      test(
        'when Enter is pressed without a selection, '
        'then it stays on the first screen',
        () async {
          await _sendKey(tester, LogicalKey.enter);
          await _pump(tester);

          expect(state.currentScreenIndex, 0);
        },
      );

      test(
        'when the Next button is focused and activated using Space key '
        'without a selection, '
        'then it stays on the first screen',
        () async {
          await _sendKey(tester, LogicalKey.arrowDown);
          await _pump(tester);
          expect(state.focusOnButton, isTrue);

          await _sendKey(tester, LogicalKey.space);
          await _pump(tester);

          expect(state.currentScreenIndex, 0);
        },
      );

      test(
        'when an option is selected using Space key and Enter is pressed, '
        'then it advances to the next screen',
        () async {
          await _sendKey(tester, LogicalKey.space);
          await _pump(tester);

          await _sendKey(tester, LogicalKey.enter);
          await _pump(tester);

          expect(state.currentScreenIndex, 1);
        },
      );
    },
  );

  group(
    'Given a multi-screen form with a single config that requires a selection '
    'and onSubmit',
    () {
      late NoctermTester tester;
      late MultiScreenFormState state;
      late _MultiScreenTestHolder holder;
      var onSubmitCalled = false;

      setUp(() async {
        onSubmitCalled = false;
        state = MultiScreenFormState([const RequiredEditorConfig()]);
        holder = _MultiScreenTestHolder(_MultiScreenTestState(state));
        tester = await NoctermTester.create(size: const Size(80, 24));
        await tester.pumpComponent(
          _MultiScreenTestApp(
            holder: holder,
            onSubmit: () => onSubmitCalled = true,
          ),
        );
      });

      tearDown(() async {
        tester.dispose();
        await holder.dispose();
      });

      test(
        'when Space activates the submit button without a selection, '
        'then onSubmit is not called',
        () async {
          await _sendKey(tester, LogicalKey.arrowDown);
          await _pump(tester);
          expect(state.focusOnButton, isTrue);

          await _sendKey(tester, LogicalKey.space);
          await _pump(tester);

          expect(onSubmitCalled, isFalse);
        },
      );

      test(
        'when Space activates the submit button after selecting an option, '
        'then onSubmit is called',
        () async {
          await _sendKey(tester, LogicalKey.space);
          await _pump(tester);

          await _sendKey(tester, LogicalKey.arrowDown);
          await _pump(tester);
          await _sendKey(tester, LogicalKey.space);
          await _pump(tester);

          expect(onSubmitCalled, isTrue);
        },
      );
    },
  );
}
