/// Strips likely PII from a transcript before it is sent to the LLM
/// (plan §13): long digit runs (phone numbers, account numbers) are
/// masked, keeping short numbers (amounts) intact.
String stripPiiForLlm(String transcript) {
  return transcript.replaceAllMapped(
    RegExp(r'\d{7,}'),
    (match) => '#' * match.group(0)!.length,
  );
}
