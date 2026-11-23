class BodyMeasurements {
  final double? waistCm;
  final double? chestCm;
  final double? armsCm;
  final double? legsCm;
  final double? hipsCm;

  const BodyMeasurements({
    this.waistCm,
    this.chestCm,
    this.armsCm,
    this.legsCm,
    this.hipsCm,
  });

  Map<String, dynamic> toMap() {
    return {
      'waistCm': waistCm,
      'chestCm': chestCm,
      'armsCm': armsCm,
      'legsCm': legsCm,
      'hipsCm': hipsCm,
    };
  }

  factory BodyMeasurements.fromMap(Map<String, dynamic> map) {
    return BodyMeasurements(
      waistCm: (map['waistCm'] as num?)?.toDouble(),
      chestCm: (map['chestCm'] as num?)?.toDouble(),
      armsCm: (map['armsCm'] as num?)?.toDouble(),
      legsCm: (map['legsCm'] as num?)?.toDouble(),
      hipsCm: (map['hipsCm'] as num?)?.toDouble(),
    );
  }
}

class ProgressEntry {
  final String id;
  final DateTime date;
  final double weightKg;
  final double? bodyFatPercentage;
  final BodyMeasurements measurements;
  final String? photoPath;
  final String? notes;

  const ProgressEntry({
    required this.id,
    required this.date,
    required this.weightKg,
    this.bodyFatPercentage,
    this.measurements = const BodyMeasurements(),
    this.photoPath,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'weightKg': weightKg,
      'bodyFatPercentage': bodyFatPercentage,
      'measurements': measurements.toMap(),
      'photoPath': photoPath,
      'notes': notes,
    };
  }

  factory ProgressEntry.fromMap(Map<String, dynamic> map) {
    return ProgressEntry(
      id: map['id'] as String? ?? '',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 70.0,
      bodyFatPercentage: (map['bodyFatPercentage'] as num?)?.toDouble(),
      measurements: map['measurements'] != null
          ? BodyMeasurements.fromMap(map['measurements'] as Map<String, dynamic>)
          : const BodyMeasurements(),
      photoPath: map['photoPath'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
