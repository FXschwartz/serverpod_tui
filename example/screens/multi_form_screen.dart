import 'package:nocterm/nocterm.dart';
import 'package:serverpod_tui/serverpod_tui.dart';

class MultiFormScreen extends StatefulComponent {
  @override
  State<StatefulComponent> createState() => MultiFormScreenState();
}

class MultiFormScreenState extends State<MultiFormScreen> {
  final _scrollController = ScrollController();
  late final _formState = MultiScreenFormState([
    InputConfig.projectName,
    BoolConfig.featureX,
    SelectConfig.database,
    SelectConfig.ides,
  ]);

  @override
  void initState() {
    super.initState();
    _formState.setValidator(InputConfig.projectName, (value) {
      if (value.isEmpty) return 'Project name required';
      return null;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _formState.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Form.multiScreen(
            state: _formState,
            scrollController: _scrollController,
            rebuild: () => setState(() {}),
            summaryDescription: 'Press Enter to finish.',
            onSubmit: () {
              _formState.nextScreen();
              setState(() {});
            },
          ),
        ),
        ButtonBar(
          buttons: [
            Button(
              name: 'Next',
              activationChar: 'Enter',
              activationKeys: const [LogicalKey.enter],
              onActivate: (_) {
                if (!_formState.hasSingleScreen && !_formState.isSummary) {
                  _formState.nextScreen();
                  setState(() {});
                }
              },
              enabled: !_formState.isSummary,
            ),
            Button(
              name: 'Back',
              activationChar: 'B',
              activationKeys: const [LogicalKey.keyB],
              onActivate: (_) {
                _formState.previousScreen();
                setState(() {});
              },
              enabled: _formState.currentScreenIndex > 0,
            ),
            Button(
              name: 'Navigate',
              activationChar: '←↑↓→',
              activationKeys: const [
                LogicalKey.arrowLeft,
                LogicalKey.arrowRight,
                LogicalKey.arrowUp,
                LogicalKey.arrowDown,
              ],
              onActivate: (key) {
                switch (key) {
                  case LogicalKey.arrowLeft:
                    _formState.focusLeft();
                    break;
                  case LogicalKey.arrowRight:
                    _formState.focusRight();
                    break;
                  case LogicalKey.arrowUp:
                    _formState.focusUp();
                    break;
                  case LogicalKey.arrowDown:
                    _formState.focusDown();
                    break;
                }
                setState(() {});
              },
              enabled: !_formState.isSummary,
            ),
            Button(
              name: 'Select',
              activationChar: 'Space',
              activationKeys: const [LogicalKey.space],
              onActivate: (_) {
                _formState.onSelect();
                setState(() {});
              },
              enabled: !_formState.isSummary,
            ),
            Button(
              name: 'Quit',
              activationChar: 'Q',
              activationKeys: const [LogicalKey.keyQ],
              onActivate: (_) => shutdownTuiApp(),
            ),
          ],
        ),
      ],
    );
  }
}

// --- Configs ---

enum InputConfig implements FormInputConfig {
  projectName(
    label: 'Project Name',
    width: 20,
    description: FormDescription(
      label: 'A unique name for your project',
      spacing: 2,
    ),
  )
  ;

  const InputConfig({
    required this.label,
    this.width = 10,
    this.description,
  });

  @override
  final String label;
  @override
  final int maxLines = 1;
  @override
  final double width;
  @override
  final String? suffixText = '';
  @override
  final FormDescription? description;
  @override
  final List<FormRequirement> requirements = const [];
}

enum BoolConfig<T extends FormConfigOption> implements FormSelectionConfig<T> {
  featureX<BoolFormConfigOption>(
    label: 'Feature X',
    options: BoolFormConfigOption.values,
    defaultOptions: {BoolFormConfigOption.disabled},
    description: FormDescription(
      label: 'Enable the experimental feature X',
      spacing: 2,
    ),
  )
  ;

  const BoolConfig({
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

enum DatabaseOption implements FormConfigOption {
  postgres('Postgres'),
  sqlite('SQLite'),
  mysql('MySQL')
  ;

  const DatabaseOption(this.label);
  @override
  final String label;
}

enum IdeOption implements FormConfigOption {
  vsCode('VS Code'),
  cursor('Cursor'),
  jetBrains('JetBrains'),
  vim('Vim')
  ;

  const IdeOption(this.label);
  @override
  final String label;
}

enum SelectConfig<T extends FormConfigOption>
    implements FormSelectionConfig<T> {
  database<DatabaseOption>(
    label: 'Database',
    options: DatabaseOption.values,
    defaultOptions: {DatabaseOption.postgres},
    description: FormDescription(
      label: 'Choose your primary database',
      spacing: 2,
    ),
  ),
  ides<IdeOption>(
    label: 'IDEs',
    options: IdeOption.values,
    multiSelect: true,
    defaultOptions: <IdeOption>{IdeOption.vsCode},
    description: FormDescription(
      label: 'Select the editors you use',
      spacing: 2,
    ),
  )
  ;

  const SelectConfig({
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
