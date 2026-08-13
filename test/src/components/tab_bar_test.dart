import 'package:nocterm/nocterm.dart';
import 'package:serverpod_tui/serverpod_tui.dart';
import 'package:test/test.dart';

void main() {
  // NoctermTestBinding is a process-wide singleton, so every test must
  // dispose its tester before the next one can call NoctermTester.create.
  late NoctermTester tester;
  tearDown(() => tester.dispose());

  group('Given tabs with activity states', () {
    test('when a tab is running then a dot precedes its label', () async {
      tester = await NoctermTester.create(size: const Size(60, 4));
      await tester.pumpComponent(
        TabBar(
          labels: const ['Server logs', 'app'],
          states: const [TabActivity.none, TabActivity.running],
          selectedTab: 0,
          onTabChanged: (_) {},
        ),
      );

      expect(tester.terminalState.getText(), contains('● app'));
    });

    test(
      'when a tab is stopped then an empty circle precedes its label',
      () async {
        tester = await NoctermTester.create(size: const Size(60, 4));
        await tester.pumpComponent(
          TabBar(
            labels: const ['Server logs', 'app'],
            states: const [TabActivity.none, TabActivity.stopped],
            selectedTab: 0,
            onTabChanged: (_) {},
          ),
        );

        expect(tester.terminalState.getText(), contains('○ app'));
      },
    );

    test('when a tab is loading then a spinner precedes its label', () async {
      tester = await NoctermTester.create(size: const Size(60, 4));
      // Wrap in a SpinnerScope so the loading frame animates; a bare
      // SpinnerIcon falls back to a static glyph without one.
      await tester.pumpComponent(
        SpinnerScope(
          active: true,
          child: TabBar(
            labels: const ['Server logs', 'app'],
            states: const [TabActivity.none, TabActivity.loading],
            selectedTab: 0,
            onTabChanged: (_) {},
          ),
        ),
      );

      final text = tester.terminalState.getText();
      // A braille spinner frame, not the solid running/stopped glyphs.
      expect(text, contains('⠋ app'));
      expect(text, isNot(contains('● app')));
    });

    test('when a tab has no activity then no indicator precedes it', () async {
      tester = await NoctermTester.create(size: const Size(60, 4));
      await tester.pumpComponent(
        TabBar(
          labels: const ['Server logs'],
          states: const [TabActivity.none],
          selectedTab: 0,
          onTabChanged: (_) {},
        ),
      );

      final text = tester.terminalState.getText();
      expect(text, isNot(contains('●')));
      expect(text, isNot(contains('○')));
    });
  });

  test(
    'Given a tab bar laid out at a fractional width '
    'when rendered inside a bordered box '
    'then the underline has no gap before the border junction',
    () async {
      tester = await NoctermTester.create(size: const Size(40, 6));
      await tester.pumpComponent(
        Container(
          decoration: BoxDecoration(
            border: BoxBorder.all(style: BoxBorderStyle.rounded),
          ),
          child: Row(
            children: [
              // Forces the bar onto fractional cells: its segments size
              // with maxWidth.toInt(), which would leave the final half
              // cell unpainted without the base rule behind them.
              const SizedBox(width: 1.5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TabBar(
                      labels: const ['Server logs'],
                      selectedTab: 0,
                      onTabChanged: (_) {},
                    ),
                    Expanded(child: const SizedBox.shrink()),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      final ts = tester.terminalState;
      // The cell beside the border keeps the underline; a truncation gap
      // here would break the line just before its junction.
      expect(ts.getTextAt(38, 2, length: 1), '━');
      expect(ts.getTextAt(39, 2, length: 1), '┥');
    },
  );

  test(
    'Given a tab bar inside a bordered box '
    'when rendered then the underline merges into both border sides',
    () async {
      tester = await NoctermTester.create(size: const Size(40, 6));
      await tester.pumpComponent(
        Container(
          decoration: BoxDecoration(
            border: BoxBorder.all(style: BoxBorderStyle.rounded),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabBar(
                labels: const ['Server logs'],
                selectedTab: 0,
                onTabChanged: (_) {},
              ),
              Expanded(child: const SizedBox.shrink()),
            ],
          ),
        ),
      );

      // The tab bar sits inside the border, so its label is on row 1 and
      // its underline on row 2. The underline's ends reach the border
      // cells and form heavy tees instead of leaving gaps.
      final ts = tester.terminalState;
      expect(ts.getTextAt(0, 2, length: 1), '┝');
      expect(ts.getTextAt(39, 2, length: 1), '┥');
      // The whole underline - junctions and segments alike - carries the
      // surrounding box border's color, so bar and border read as one
      // frame.
      final borderColor = ServerpodThemeData.dark.subtleDivider;
      expect(ts.getCellAt(0, 2)?.style.color, borderColor);
      expect(ts.getCellAt(20, 2)?.style.color, borderColor);
    },
  );

  test(
    'Given a tab bar with no surrounding border '
    'when rendered '
    'then the underline ends paint no stray junction arms',
    () async {
      tester = await NoctermTester.create(size: const Size(40, 4));
      await tester.pumpComponent(
        Container(
          padding: EdgeInsets.all(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabBar(
                labels: const ['Server logs'],
                selectedTab: 0,
                onTabChanged: (_) {},
              ),
              Expanded(child: const SizedBox.shrink()),
            ],
          ),
        ),
      );

      // The base rule reaches one cell outside the tab bar on each side,
      // but with nothing there to join it leaves those cells untouched.
      final ts = tester.terminalState;
      expect(ts.getTextAt(0, 2, length: 1), ' ');
      expect(ts.getTextAt(39, 2, length: 1), ' ');
    },
  );

  test(
    'Given fewer states than labels '
    'when rendered '
    'then tabs without a state get no indicator',
    () async {
      tester = await NoctermTester.create(size: const Size(60, 4));
      await tester.pumpComponent(
        TabBar(
          labels: const ['Server logs', 'app'],
          states: const [TabActivity.running],
          selectedTab: 0,
          onTabChanged: (_) {},
        ),
      );

      final text = tester.terminalState.getText();
      expect(text, contains('● Server logs'));
      // The second tab has no corresponding state, so no indicator is drawn.
      expect(text, isNot(contains('● app')));
    },
  );
}
