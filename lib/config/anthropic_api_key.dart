/// Anthropic key from `--dart-define-from-file=secrets.json` (D42).
///
/// Copy `secrets.example.json` → `secrets.json`, paste your key, and
/// launch with that file. `secrets.json` is gitignored.
const anthropicApiKeyFromCode = String.fromEnvironment('ANTHROPIC_API_KEY');
