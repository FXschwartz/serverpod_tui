import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:nocterm/nocterm.dart';

/// A clipboard utility to invoke, with its arguments.
@immutable
class ClipboardCommand {
  const ClipboardCommand(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}

/// Starts a subprocess; mirrors [Process.start]. Injectable for testing.
typedef ProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

/// The ordered clipboard tools to try for [operatingSystem] (a value from
/// [Platform.operatingSystem]).
///
/// macOS and Windows ship a single guaranteed tool. Linux has none built in,
/// so several are tried: Wayland's `wl-copy` first, then the X11 tools.
List<ClipboardCommand> clipboardCommandsFor(String operatingSystem) {
  return switch (operatingSystem) {
    'macos' => const [ClipboardCommand('pbcopy', [])],
    'windows' => const [ClipboardCommand('clip', [])],
    _ => const [
      ClipboardCommand('wl-copy', []),
      ClipboardCommand('xclip', ['-selection', 'clipboard']),
      ClipboardCommand('xsel', ['--clipboard', '--input']),
    ],
  };
}

/// Copies [text] to the system clipboard.
///
/// Two mechanisms are used together because neither covers every setup:
/// - OSC 52 (via nocterm's [ClipboardManager]) is terminal-agnostic and works
///   over SSH, but many terminals don't honour it (e.g. macOS Terminal.app).
/// - The native clipboard tool ([nativeCopy]) is reliable locally but is
///   platform-specific and absent on headless Linux.
///
/// The native tool is only invoked when attached to a terminal, so the test
/// suite (where stdout is not a terminal) never spawns a subprocess. The
/// internal buffer is always updated, so [ClipboardManager.paste] reflects the
/// last copy regardless.
void copyToClipboard(String text) {
  ClipboardManager.copy(text);

  if (stdout.hasTerminal) {
    unawaited(nativeCopy(text));
  }
}

/// Pipes [text] to the platform clipboard utility, trying the candidates from
/// [clipboardCommandsFor] in order and stopping at the first that starts.
///
/// Returns whether a tool accepted the text. Silently returns false when none
/// is available (e.g. headless Linux). [operatingSystem] and [startProcess]
/// are injectable so the platform behaviour can be tested off-platform.
@visibleForTesting
Future<bool> nativeCopy(
  String text, {
  String? operatingSystem,
  ProcessStarter? startProcess,
}) async {
  final start = startProcess ?? Process.start;
  final commands = clipboardCommandsFor(
    operatingSystem ?? Platform.operatingSystem,
  );

  for (final command in commands) {
    try {
      final process = await start(command.executable, command.arguments);
      process.stdin
        ..write(text)
        ..close();
      return true;
    } catch (_) {
      // Tool not installed or failed to start; try the next candidate.
    }
  }
  return false;
}
