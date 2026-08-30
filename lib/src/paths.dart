import 'dart:io';

/// Where PopupBits apps keep machine-local data they can re-create.
///
/// Each platform's convention for exactly that: not documents, and not the
/// app's own directory, which may be read-only and is replaced wholesale on
/// update. Models are the bulk of it, but anything an app can re-download —
/// native runtimes, caches — belongs under here too, so several apps share
/// one copy instead of each carrying its own.
String popupBitsDataDir() {
  final env = Platform.environment;
  final sep = Platform.pathSeparator;

  if (Platform.isWindows) {
    // Local rather than roaming: this is large and re-downloadable, and
    // roaming profiles are not the place for a gigabyte of weights.
    final base =
        env['LOCALAPPDATA'] ?? '${env['USERPROFILE']}${sep}AppData${sep}Local';
    return '$base${sep}PopupBits';
  }
  if (Platform.isMacOS) {
    return '${env['HOME']}${sep}Library${sep}Application Support${sep}PopupBits';
  }
  final xdg = env['XDG_DATA_HOME'];
  final base = (xdg != null && xdg.isNotEmpty)
      ? xdg
      : '${env['HOME']}$sep.local${sep}share';
  return '$base${sep}popupbits';
}
