import 'package:nocterm/nocterm.dart';
import 'package:serverpod_tui/src/components/spinner.dart';
import 'package:serverpod_tui/src/serverpod_theme.dart';

/// Activity state shown as a leading indicator on a tab.
enum TabActivity {
  /// No indicator.
  none,

  /// A dot in the theme's success color.
  running,

  /// A spinner; animated when a [SpinnerScope] ancestor is present, otherwise a
  /// static fallback glyph.
  loading,

  /// An empty circle in the theme's muted color.
  stopped,
}

/// A tab bar component.
class TabBar extends StatelessComponent {
  const TabBar({
    super.key,
    required this.labels,
    required this.selectedTab,
    required this.onTabChanged,
    this.states = const [],
  });

  final List<String> labels;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  /// Per-tab activity indicators, aligned by index with [labels]. Indices
  /// without an entry (or set to [TabActivity.none]) render no indicator.
  final List<TabActivity> states;

  @override
  Component build(BuildContext context) {
    final tabComponents = <Component>[];

    for (int i = 0; i < labels.length; i += 1) {
      tabComponents.add(
        _TabSpacing(
          width: 1,
          type: selectedTab == i
              ? _TabSpacingType.shortRight
              : _TabSpacingType.full,
        ),
      );

      // Tab.
      tabComponents.add(
        _Tab(
          label: labels[i],
          selected: i == selectedTab,
          state: i < states.length ? states[i] : TabActivity.none,
          onTap: () => onTabChanged(i),
        ),
      );

      // Spacing after tab.
      _TabSpacingType spacingType;
      if (i == selectedTab) {
        spacingType = _TabSpacingType.shortLeft;
      } else {
        spacingType = _TabSpacingType.full;
      }

      tabComponents.add(_TabSpacing(width: 2, type: spacingType));
    }

    // Fill remaining space after last tab.
    tabComponents.add(
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _TabSpacing(
              width: constraints.maxWidth.toInt(),
              type: _TabSpacingType.full,
            );
          },
        ),
      ),
    );

    return Stack(
      children: [
        // A full-width base rule painted behind the tab segments, in the
        // border's color like the segments themselves. It fills the cells
        // fractional pane widths leave uncovered (the segments size with
        // maxWidth.toInt(), truncating half cells), and its ends reach one
        // cell outside the bar to merge the underline into a surrounding
        // box border (┝/┥). Ends with no border to join paint nothing.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Divider(
            style: DividerStyle.bold,
            indent: -1,
            endIndent: -1,
            color: ServerpodTheme.of(context).subtleDivider,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: tabComponents,
        ),
      ],
    );
  }
}

class _Tab extends StatelessComponent {
  const _Tab({
    required this.label,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final TabActivity state;
  final VoidCallback onTap;

  @override
  Component build(BuildContext context) {
    final theme = ServerpodTheme.of(context);
    final hasIndicator = state != TabActivity.none;
    // The indicator and its trailing space occupy two columns, so the
    // selection underline must cover them too.
    final underlineWidth = label.length + (hasIndicator ? 2 : 0);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasIndicator) ...[
                TabActivityIndicator(state),
                const Text(' '),
              ],
              Text(
                label,
                style: TextStyle(
                  color: theme.brightText,
                  fontWeight: selected ? FontWeight.normal : FontWeight.dim,
                ),
              ),
            ],
          ),
          Text(
            ''.padLeft(underlineWidth, '━'),
            // The selection highlight keeps its accent color; every other
            // underline segment matches the surrounding box border.
            style: TextStyle(
              color: selected ? theme.activationKey : theme.subtleDivider,
            ),
          ),
        ],
      ),
    );
  }
}

/// A leading status indicator for a tab or app row.
///
/// Renders the glyph for [activity] as a single [Text] so the widget's
/// component type stays stable across state changes - a type flip in a slot
/// (e.g. a spinner becoming a static glyph) can leave stale cells behind. The
/// loading spinner animates off the shared [SpinnerScope] when one is present,
/// otherwise it shows a static frame. The colour follows the theme regardless
/// of selection, so app state stays readable at a glance.
class TabActivityIndicator extends StatefulComponent {
  const TabActivityIndicator(this.activity, {super.key});

  final TabActivity activity;

  @override
  State<TabActivityIndicator> createState() => _TabActivityIndicatorState();
}

class _TabActivityIndicatorState extends State<TabActivityIndicator> {
  SpinnerNotifier? _notifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = SpinnerScope.of(context);
    if (notifier != _notifier) {
      _notifier?.removeListener(_onFrame);
      _notifier = notifier;
      _notifier?.addListener(_onFrame);
    }
  }

  void _onFrame() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notifier?.removeListener(_onFrame);
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final theme = ServerpodTheme.of(context);
    final (glyph, color) = switch (component.activity) {
      TabActivity.none => (' ', null),
      TabActivity.running => ('●', theme.success),
      TabActivity.loading => (_notifier?.value ?? '●', theme.spinner),
      TabActivity.stopped => ('○', theme.debugLevel),
    };
    return Text(glyph, style: color == null ? null : TextStyle(color: color));
  }
}

enum _TabSpacingType { full, shortLeft, shortRight }

class _TabSpacing extends StatelessComponent {
  final int width;
  final _TabSpacingType type;

  const _TabSpacing({required this.width, required this.type});

  @override
  Component build(BuildContext context) {
    String underline;
    switch (type) {
      case _TabSpacingType.full:
        underline = ''.padLeft(width, '━');
        break;
      case _TabSpacingType.shortLeft:
        underline = '╺'.padRight(width, '━');
        break;
      case _TabSpacingType.shortRight:
        underline = '╸'.padLeft(width, '━');
        break;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(''.padLeft(width)),
        // The underline shares the surrounding box border's color and
        // weight so bar and border read as one frame.
        Text(
          underline,
          style: TextStyle(color: ServerpodTheme.of(context).subtleDivider),
        ),
      ],
    );
  }
}
