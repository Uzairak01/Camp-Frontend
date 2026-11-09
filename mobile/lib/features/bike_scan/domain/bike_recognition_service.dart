/// Data model representing the typed result of motorcycle image recognition.
/// Contains only the physical specifications identified by recognition.
class BikeRecognitionResult {
  const BikeRecognitionResult({
    this.make,
    this.model,
    this.year,
    this.displacementCc,
    this.tankCapacityLiters,
    this.category,
    this.confidence,
  });

  final String? make;
  final String? model;
  final int? year;
  final int? displacementCc;
  final double? tankCapacityLiters;
  final String? category;
  final double? confidence;
}

/// Abstract interface for motorcycle image recognition services.
///
/// Note: A real implementation needs a backend call (Firebase AI Logic with Gemini),
/// parked for the Firebase phase. No mock service or fake detection is retained in production code.
abstract class BikeRecognitionService {
  Future<BikeRecognitionResult?> recognize(String imagePath);
}
