import 'package:nocterm/nocterm.dart';
import 'package:serverpod_tui/serverpod_tui.dart';

class FormScreen extends StatefulComponent {
  @override
  State<StatefulComponent> createState() => FormScreenState();
}

class FormScreenState extends State<FormScreen> {
  final scrollController = ScrollController();
  final formState = FormState([
    InputConfig.projectId,
    ...SelectionConfig.values,
  ]);

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Form(
            state: formState,
            scrollController: scrollController,
            rebuild: () => setState(() {}),
          ),
        ),
        ButtonBar(
          buttons: [
            Button(
              name: 'Continue',
              activationChar: 'Enter',
              activationKeys: const [LogicalKey.enter],
              enabled: false,
              onActivate: (_) {},
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
                  case LogicalKey.arrowDown:
                    formState.focusDown();
                    if (formState.focusedConfigIndex == 0) {
                      scrollController.scrollToStart();
                    } else {
                      scrollController.scrollDown(3);
                    }
                    setState(() {});
                    break;
                  case LogicalKey.arrowUp:
                    formState.focusUp();
                    if (formState.focusedConfigIndex ==
                        formState.maxFocusedConfigIndex) {
                      scrollController.scrollToEnd();
                    } else {
                      scrollController.scrollUp(3);
                    }
                    setState(() {});
                    break;
                  case LogicalKey.arrowLeft:
                    formState.focusLeft();
                    setState(() {});
                    break;
                  case LogicalKey.arrowRight:
                    formState.focusRight();
                    setState(() {});
                    break;
                  case LogicalKey.space:
                    formState.onSelect();
                    setState(() {});
                    break;
                }
                setState(() {});
              },
            ),
            Button(
              name: 'Select',
              activationChar: 'Space',
              activationKeys: const [LogicalKey.space],
              onActivate: (_) {
                formState.onSelect();
                setState(() {});
              },
            ),
            Button(
              name: 'Quit',
              activationChar: 'Q',
              activationKeys: const [LogicalKey.keyQ],
              onActivate: (_) {
                shutdownTuiApp();
              },
            ),
          ],
        ),
      ],
    );
  }
}

enum InputConfig<T extends FormConfigOption> implements FormInputConfig {
  projectId(
    label: 'Project ID',
    description: FormDescription(
      label: 'A unique identifier for your project',
      spacing: 2,
    ),
    suffixText: '.serverpod',
  )
  ;

  const InputConfig({
    required this.label,
    this.maxLines = 1,
    this.width = 10,
    this.suffixText = '',
    this.requirements = const [],
    this.description,
  });

  @override
  final String label;

  @override
  final int maxLines;

  @override
  final double width;

  @override
  final String? suffixText;

  @override
  final FormDescription? description;

  @override
  final List<FormRequirement> requirements;
}

enum SelectionConfig<T extends FormConfigOption>
    implements FormSelectionConfig<T> {
  database<DatabaseConfigOption>(
    label: 'Database',
    options: DatabaseConfigOption.values,
    defaultOptions: {DatabaseConfigOption.postgres},
  ),
  auth<BoolFormConfigOption>(
    label: 'Authentication',
    options: BoolFormConfigOption.values,
    defaultOptions: {BoolFormConfigOption.enabled},
    description: FormDescription(
      label:
          'Enable authentication if you want your users to be able to sign in with email or social logins.',
      spacing: 1,
    ),
    requirements: [
      FormRequirement(
        config: SelectionConfig.database,
        configOptions: {DatabaseConfigOption.postgres},
      ),
    ],
  ),
  ide<IdeOption>(
    label: 'IDEs',
    options: IdeOption.values,
    multiSelect: true,
    defaultOptions: <IdeOption>{},
    description: FormDescription(
      label: 'Select the editors and agents you are planning to use',
      spacing: 2,
    ),
  )
  ;

  const SelectionConfig({
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

enum DatabaseConfigOption implements FormConfigOption {
  postgres('Postgres'),
  sqlite('SQLite'),
  none('None')
  ;

  const DatabaseConfigOption(this.label);

  @override
  final String label;
}

enum IdeOption implements FormConfigOption {
  antigravity('Antigravity'),
  codex('Codex'),
  claude('Claude'),
  cursor('Cursor'),
  openCode('OpenCode'),
  vsCode('VS Code')
  ;

  const IdeOption(this.label);

  @override
  final String label;
}
