// Path utilities for the record tree's "slash-prefixed and slash-suffixed"
// folder path convention. These are pure functions with no dependency on
// RecordTree state.

/// Return the parent folder path of [path].
///
/// e.g. "/work/flutter/" -> "/work/"
String dirname(String path) {
  // 1. Defense: if root dir or empty, its parent can only be root dir
  if (path == '/' || path.isEmpty) return '/';

  // 2. Search backward for slash from second-to-last position (skip the mandatory trailing slash)
  // e.g.: "/work/flutter/" length is 14, start from index 12 (i.e. 'r') searching backward for '/'
  final lastSlashIndex = path.lastIndexOf('/', path.length - 2);

  // 3. Safe fallback: if not found, or slash is at the very beginning (meaning it's a first-level dir, e.g. "/work/")
  if (lastSlashIndex <= 0) {
    return '/';
  }

  // 4. Perform a single substring cut (preserve to slash position, since substring is left-inclusive right-exclusive,
  // to include the slash itself, end index must be lastSlashIndex + 1)
  // e.g.: "/work/flutter/" → find '/' at position 5 → substring(0, 6) → get "/work/"
  return path.substring(0, lastSlashIndex + 1);
}

/// Node name extraction function tailored for "slash-prefixed and slash-suffixed" tree structures
String basename(String path) {
  // 1. Defense: if root dir or empty, name is empty (or you could choose to return '/')
  if (path == '/' || path.isEmpty) return '';

  // 2. Strip trailing slash (since our convention is folders must end with /)
  // e.g. "/work/flutter/" → "/work/flutter"
  final cleanPath = path.endsWith('/') ? path.substring(0, path.length - 1) : path;

  // 3. Find the position of the last slash
  final lastSlashIndex = cleanPath.lastIndexOf('/');

  // 4. If no slash, it's itself a relative path standalone (e.g. "flutter")
  if (lastSlashIndex == -1) return cleanPath;

  // 5. Extract all characters after the last slash
  // e.g. "/work/flutter" → extract from position 5 onward → return "flutter"
  return cleanPath.substring(lastSlashIndex + 1);
}

/// Ensure path ends with /
String ensurePathFormat(String path) {
  if (path == '/' || path.isEmpty) return '/';
  if (!path.endsWith('/')) path += '/';
  if (!path.startsWith('/')) path = '/$path';
  return path.replaceAll('//', '/'); // Guard against double slashes
}
