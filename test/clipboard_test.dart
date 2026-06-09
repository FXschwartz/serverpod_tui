import 'dart:async';
import 'dart:io';

import 'package:serverpod_tui/src/clipboard.dart';
import 'package:test/test.dart';

/// Records each [ProcessStarter] invocation and returns a fake process whose
/// stdin captures what was written. Executables named in [failing] throw, so
/// fallback ordering can be exercised.
class _RecordingStarter {
  _RecordingStarter({this.failing = const {}});

  final Set<String> failing;
  final List<String> startedExecutables = [];
  final List<List<String>> startedArguments = [];
  final Map<String, _FakeStdin> stdinByExecutable = {};

  ProcessStarter get start => (executable, arguments) async {
    startedExecutables.add(executable);
    startedArguments.add(arguments);
    if (failing.contains(executable)) {
      throw ProcessException(executable, arguments, 'not found');
    }
    final stdin = _FakeStdin();
    stdinByExecutable[executable] = stdin;
    return _FakeProcess(stdin);
  };
}

class _FakeProcess implements Process {
  _FakeProcess(this.stdin);

  @override
  final IOSink stdin;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeStdin implements IOSink {
  final StringBuffer written = StringBuffer();
  bool closed = false;

  @override
  void write(Object? object) => written.write(object);

  @override
  Future<void> close() async => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('Given the per-platform command list', () {
    test('when on macOS then pbcopy is the only tool', () {
      final commands = clipboardCommandsFor('macos');

      expect(commands, hasLength(1));
      expect(commands.single.executable, 'pbcopy');
      expect(commands.single.arguments, isEmpty);
    });

    test('when on Windows then clip is the only tool', () {
      final commands = clipboardCommandsFor('windows');

      expect(commands, hasLength(1));
      expect(commands.single.executable, 'clip');
    });

    test('when on Linux then Wayland is tried before the X11 tools', () {
      final commands = clipboardCommandsFor('linux');

      expect(
        commands.map((c) => c.executable),
        ['wl-copy', 'xclip', 'xsel'],
      );
      expect(commands[1].arguments, ['-selection', 'clipboard']);
      expect(commands[2].arguments, ['--clipboard', '--input']);
    });

    test('when on an unknown platform then the Linux tools are used', () {
      expect(
        clipboardCommandsFor('fuchsia').map((c) => c.executable),
        ['wl-copy', 'xclip', 'xsel'],
      );
    });
  });

  group('Given a macOS environment', () {
    late _RecordingStarter starter;

    setUp(() => starter = _RecordingStarter());

    test('when copying then pbcopy is invoked', () async {
      final copied = await nativeCopy(
        'secret',
        operatingSystem: 'macos',
        startProcess: starter.start,
      );

      expect(copied, isTrue);
      expect(starter.startedExecutables, ['pbcopy']);
    });

    test('when copying then the text is written to stdin and closed', () async {
      await nativeCopy(
        'secret',
        operatingSystem: 'macos',
        startProcess: starter.start,
      );

      final stdin = starter.stdinByExecutable['pbcopy']!;
      expect(stdin.written.toString(), 'secret');
      expect(stdin.closed, isTrue);
    });
  });

  group('Given a Windows environment', () {
    test('when copying then clip is invoked with the text', () async {
      final starter = _RecordingStarter();

      final copied = await nativeCopy(
        'secret',
        operatingSystem: 'windows',
        startProcess: starter.start,
      );

      expect(copied, isTrue);
      expect(starter.startedExecutables, ['clip']);
      expect(starter.stdinByExecutable['clip']!.written.toString(), 'secret');
    });
  });

  group('Given a Linux environment', () {
    test(
      'when the first tool is available then no fallback is tried',
      () async {
        final starter = _RecordingStarter();

        final copied = await nativeCopy(
          'secret',
          operatingSystem: 'linux',
          startProcess: starter.start,
        );

        expect(copied, isTrue);
        expect(starter.startedExecutables, ['wl-copy']);
      },
    );

    test('when wl-copy is missing then it falls back to xclip', () async {
      final starter = _RecordingStarter(failing: {'wl-copy'});

      final copied = await nativeCopy(
        'secret',
        operatingSystem: 'linux',
        startProcess: starter.start,
      );

      expect(copied, isTrue);
      expect(starter.startedExecutables, ['wl-copy', 'xclip']);
      expect(starter.stdinByExecutable['xclip']!.written.toString(), 'secret');
    });

    test('when only xsel is available then it falls through to it', () async {
      final starter = _RecordingStarter(failing: {'wl-copy', 'xclip'});

      final copied = await nativeCopy(
        'secret',
        operatingSystem: 'linux',
        startProcess: starter.start,
      );

      expect(copied, isTrue);
      expect(starter.startedExecutables, ['wl-copy', 'xclip', 'xsel']);
    });

    test(
      'when no clipboard tool is available then it fails silently',
      () async {
        final starter = _RecordingStarter(
          failing: {'wl-copy', 'xclip', 'xsel'},
        );

        final copied = await nativeCopy(
          'secret',
          operatingSystem: 'linux',
          startProcess: starter.start,
        );

        expect(copied, isFalse);
        expect(starter.startedExecutables, ['wl-copy', 'xclip', 'xsel']);
      },
    );
  });
}
