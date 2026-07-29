Duration syncRetryDelay(int attemptCount) {
  final exponent = (attemptCount - 1).clamp(0, 10);
  final seconds = 5 * (1 << exponent);
  return Duration(seconds: seconds.clamp(5, 3600));
}
