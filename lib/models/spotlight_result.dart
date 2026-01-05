class SpotlightResult {
  final int startMs;
  final int endMs;
  final String summary;
  final double confidence;

  SpotlightResult({required this.startMs, required this.endMs, required this.summary, required this.confidence});

  factory SpotlightResult.fromJson(Map<String, dynamic> json) {
    return SpotlightResult(
      startMs: json['start_ms'] ?? 0,
      endMs: json['end_ms'] ?? 0,
      summary: json['summary'] ?? "Topic found.",
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }
}
