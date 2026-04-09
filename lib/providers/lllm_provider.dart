abstract class LlmProvider {
  Future<String> generate(String prompt);
  Future<String> generateWithSystem(String system, String user);
}

class LlmError implements Exception {
  LlmError(this.message);
  final String message;
  @override
  String toString() => message;
}
