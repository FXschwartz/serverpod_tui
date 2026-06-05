## 0.1.0-rc.7

Improved form UI and added support for optional description for form configurations.
Added alert messages: `TuiAppStateHolder.showAlert` pins a message to the bottom line until dismissed with Escape. A segment marked with angle brackets (e.g. `code: <123456>`) is auto-copied to the clipboard and re-copied with C.

## 0.1.0-rc.6

Fixed buttons activating on Ctrl, Alt, and Meta key combinations so app-level shortcuts reach their handlers.
Fixed the Ctrl-C hint toggling remounting the whole app subtree and resetting its state.
Fixed text selection getting swallowed up on Windows.

## 0.1.0-rc.5

Added support for form input validation and suffix text.

## 0.1.0-rc.4

Updated Ctrl-C behavior to match common CLI tools: copies the current selection if there is one, otherwise a first press arms exit and a second press within two seconds exits gracefully.

## 0.1.0-rc.3

Lowered minimum Dart SDK to 3.10.3

## 0.1.0-rc.2

Fixed terminal restoration on Windows

## 0.1.0-rc.1

- Initial version.
