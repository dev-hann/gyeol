abstract class LlmProvider {
  Future<String> generate(String prompt);
  Future<String> generateWithSystem(String system, String user);
}

class LlmError implements Exception {
  final String message;
  LlmError(this.message);
  @override
  String toString() => message;
}
