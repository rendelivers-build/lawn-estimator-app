/// Shared data models for the Lawn Estimator app.
///
/// These field names are a cross-module contract: other modules
/// (estimates, measure, materials, pricing) import these classes and
/// persist them with sqflite using the snake_case keys in [toMap].
library;

import 'package:uuid/uuid.dart';

/// Whether the measured lawn area has been confirmed by the estimator.
enum ConfirmationStatus { confirmed, unconfirmed }

/// A single lawn estimate job.
class Estimate {
  final String id;
  final String name;
  final String addressLabel;
  final String? placeId;
  final double centerLat;
  final double centerLng;
  final double areaFt2;
  final ConfirmationStatus confirmationStatus;
  final String? photoPath;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Estimate({
    required this.id,
    required this.name,
    required this.addressLabel,
    this.placeId,
    required this.centerLat,
    required this.centerLng,
    required this.areaFt2,
    this.confirmationStatus = ConfirmationStatus.unconfirmed,
    this.photoPath,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  Estimate copyWith({
    String? id,
    String? name,
    String? addressLabel,
    String? placeId,
    double? centerLat,
    double? centerLng,
    double? areaFt2,
    ConfirmationStatus? confirmationStatus,
    String? photoPath,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Estimate(
      id: id ?? this.id,
      name: name ?? this.name,
      addressLabel: addressLabel ?? this.addressLabel,
      placeId: placeId ?? this.placeId,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      areaFt2: areaFt2 ?? this.areaFt2,
      confirmationStatus: confirmationStatus ?? this.confirmationStatus,
      photoPath: photoPath ?? this.photoPath,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Creates a new estimate with a fresh UUID and current timestamps.
  factory Estimate.create({
    required String name,
    required String addressLabel,
    String? placeId,
    required double centerLat,
    required double centerLng,
    double areaFt2 = 0,
  }) {
    final now = DateTime.now();
    return Estimate(
      id: const Uuid().v4(),
      name: name,
      addressLabel: addressLabel,
      placeId: placeId,
      centerLat: centerLat,
      centerLng: centerLng,
      areaFt2: areaFt2,
      confirmationStatus: ConfirmationStatus.unconfirmed,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address_label': addressLabel,
      'place_id': placeId,
      'center_lat': centerLat,
      'center_lng': centerLng,
      'area_ft2': areaFt2,
      'confirmation_status': confirmationStatus.name,
      'photo_path': photoPath,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Estimate.fromMap(Map<String, dynamic> map) {
    return Estimate(
      id: map['id'] as String,
      name: map['name'] as String,
      addressLabel: map['address_label'] as String,
      placeId: map['place_id'] as String?,
      centerLat: (map['center_lat'] as num).toDouble(),
      centerLng: (map['center_lng'] as num).toDouble(),
      areaFt2: (map['area_ft2'] as num).toDouble(),
      confirmationStatus: ConfirmationStatus.values.firstWhere(
        (s) => s.name == map['confirmation_status'],
        orElse: () => ConfirmationStatus.unconfirmed,
      ),
      photoPath: map['photo_path'] as String?,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// One measured lawn area within an estimate (e.g. front yard, back yard).
class LawnZone {
  final String id;
  final String estimateId;
  final String label;
  final int sequence;
  final double areaM2;

  const LawnZone({
    required this.id,
    required this.estimateId,
    required this.label,
    required this.sequence,
    required this.areaM2,
  });

  LawnZone copyWith({
    String? id,
    String? estimateId,
    String? label,
    int? sequence,
    double? areaM2,
  }) {
    return LawnZone(
      id: id ?? this.id,
      estimateId: estimateId ?? this.estimateId,
      label: label ?? this.label,
      sequence: sequence ?? this.sequence,
      areaM2: areaM2 ?? this.areaM2,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'estimate_id': estimateId,
      'label': label,
      'sequence': sequence,
      'area_m2': areaM2,
    };
  }

  factory LawnZone.fromMap(Map<String, dynamic> map) {
    return LawnZone(
      id: map['id'] as String,
      estimateId: map['estimate_id'] as String,
      label: map['label'] as String,
      sequence: (map['sequence'] as num).toInt(),
      areaM2: (map['area_m2'] as num).toDouble(),
    );
  }
}

/// One polygon vertex of a lawn zone, ordered by [sequence].
class Vertex {
  final String id;
  final String zoneId;
  final int sequence;
  final double latitude;
  final double longitude;

  const Vertex({
    required this.id,
    required this.zoneId,
    required this.sequence,
    required this.latitude,
    required this.longitude,
  });

  Vertex copyWith({
    String? id,
    String? zoneId,
    int? sequence,
    double? latitude,
    double? longitude,
  }) {
    return Vertex(
      id: id ?? this.id,
      zoneId: zoneId ?? this.zoneId,
      sequence: sequence ?? this.sequence,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'zone_id': zoneId,
      'sequence': sequence,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Vertex.fromMap(Map<String, dynamic> map) {
    return Vertex(
      id: map['id'] as String,
      zoneId: map['zone_id'] as String,
      sequence: (map['sequence'] as num).toInt(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
    );
  }
}

/// Material quantity calculation for an estimate
/// (fertilizer, seed, etc.).
class MaterialEstimate {
  final String id;
  final String estimateId;
  final String materialType;
  final double? ratePer1000;
  final double? packageSizeLb;
  final double? wastePercent;
  final double? unitCoverageFt2;
  final double exactQuantity;
  final double purchaseUnits;
  final DateTime updatedAt;

  const MaterialEstimate({
    required this.id,
    required this.estimateId,
    required this.materialType,
    this.ratePer1000,
    this.packageSizeLb,
    this.wastePercent,
    this.unitCoverageFt2,
    required this.exactQuantity,
    required this.purchaseUnits,
    required this.updatedAt,
  });

  MaterialEstimate copyWith({
    String? id,
    String? estimateId,
    String? materialType,
    double? ratePer1000,
    double? packageSizeLb,
    double? wastePercent,
    double? unitCoverageFt2,
    double? exactQuantity,
    double? purchaseUnits,
    DateTime? updatedAt,
  }) {
    return MaterialEstimate(
      id: id ?? this.id,
      estimateId: estimateId ?? this.estimateId,
      materialType: materialType ?? this.materialType,
      ratePer1000: ratePer1000 ?? this.ratePer1000,
      packageSizeLb: packageSizeLb ?? this.packageSizeLb,
      wastePercent: wastePercent ?? this.wastePercent,
      unitCoverageFt2: unitCoverageFt2 ?? this.unitCoverageFt2,
      exactQuantity: exactQuantity ?? this.exactQuantity,
      purchaseUnits: purchaseUnits ?? this.purchaseUnits,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Creates a new material estimate with a fresh UUID.
  factory MaterialEstimate.create({
    required String estimateId,
    required String materialType,
    double? ratePer1000,
    double? packageSizeLb,
    double? wastePercent,
    double? unitCoverageFt2,
    double exactQuantity = 0,
    double purchaseUnits = 0,
  }) {
    return MaterialEstimate(
      id: const Uuid().v4(),
      estimateId: estimateId,
      materialType: materialType,
      ratePer1000: ratePer1000,
      packageSizeLb: packageSizeLb,
      wastePercent: wastePercent,
      unitCoverageFt2: unitCoverageFt2,
      exactQuantity: exactQuantity,
      purchaseUnits: purchaseUnits,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'estimate_id': estimateId,
      'material_type': materialType,
      'rate_per_1000': ratePer1000,
      'package_size_lb': packageSizeLb,
      'waste_percent': wastePercent,
      'unit_coverage_ft2': unitCoverageFt2,
      'exact_quantity': exactQuantity,
      'purchase_units': purchaseUnits,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MaterialEstimate.fromMap(Map<String, dynamic> map) {
    return MaterialEstimate(
      id: map['id'] as String,
      estimateId: map['estimate_id'] as String,
      materialType: map['material_type'] as String,
      ratePer1000: (map['rate_per_1000'] as num?)?.toDouble(),
      packageSizeLb: (map['package_size_lb'] as num?)?.toDouble(),
      wastePercent: (map['waste_percent'] as num?)?.toDouble(),
      unitCoverageFt2: (map['unit_coverage_ft2'] as num?)?.toDouble(),
      exactQuantity: (map['exact_quantity'] as num).toDouble(),
      purchaseUnits: (map['purchase_units'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// One priced service line on an estimate.
class LineItem {
  final String id;
  final String estimateId;
  final String service;
  final double quantity;
  final String unit;
  final String unitPrice;

  /// Where the price came from: 'owner' or 'area_default'.
  final String rateSource;
  final double extendedAmount;
  final DateTime updatedAt;

  const LineItem({
    required this.id,
    required this.estimateId,
    required this.service,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.rateSource,
    required this.extendedAmount,
    required this.updatedAt,
  });

  LineItem copyWith({
    String? id,
    String? estimateId,
    String? service,
    double? quantity,
    String? unit,
    String? unitPrice,
    String? rateSource,
    double? extendedAmount,
    DateTime? updatedAt,
  }) {
    return LineItem(
      id: id ?? this.id,
      estimateId: estimateId ?? this.estimateId,
      service: service ?? this.service,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      rateSource: rateSource ?? this.rateSource,
      extendedAmount: extendedAmount ?? this.extendedAmount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Creates a new line item with a fresh UUID.
  /// [extendedAmount] is derived from [quantity] × [unitPrice].
  factory LineItem.create({
    required String estimateId,
    required String service,
    required double quantity,
    required String unit,
    required String unitPrice,
    required String rateSource,
  }) {
    final extended =
        quantity * (double.tryParse(unitPrice) ?? 0);
    return LineItem(
      id: const Uuid().v4(),
      estimateId: estimateId,
      service: service,
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
      rateSource: rateSource,
      extendedAmount: extended,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'estimate_id': estimateId,
      'service': service,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'rate_source': rateSource,
      'extended_amount': extendedAmount,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory LineItem.fromMap(Map<String, dynamic> map) {
    return LineItem(
      id: map['id'] as String,
      estimateId: map['estimate_id'] as String,
      service: map['service'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      unitPrice: map['unit_price'] as String,
      rateSource: map['rate_source'] as String,
      extendedAmount: (map['extended_amount'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// Per-service pricing configuration.
class PricingSettings {
  final String service;
  final double? ownerPrice;
  final String unit;
  final double? areaDefaultPrice;
  final DateTime updatedAt;

  const PricingSettings({
    required this.service,
    this.ownerPrice,
    required this.unit,
    this.areaDefaultPrice,
    required this.updatedAt,
  });

  PricingSettings copyWith({
    String? service,
    double? ownerPrice,
    String? unit,
    double? areaDefaultPrice,
    DateTime? updatedAt,
  }) {
    return PricingSettings(
      service: service ?? this.service,
      ownerPrice: ownerPrice ?? this.ownerPrice,
      unit: unit ?? this.unit,
      areaDefaultPrice: areaDefaultPrice ?? this.areaDefaultPrice,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'service': service,
      'owner_price': ownerPrice,
      'unit': unit,
      'area_default_price': areaDefaultPrice,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PricingSettings.fromMap(Map<String, dynamic> map) {
    return PricingSettings(
      service: map['service'] as String,
      ownerPrice: (map['owner_price'] as num?)?.toDouble(),
      unit: map['unit'] as String,
      areaDefaultPrice: (map['area_default_price'] as num?)?.toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// A full estimate with all related records loaded.
class EstimateFull {
  final Estimate estimate;
  final List<LawnZone> zones;

  /// Vertices keyed by zone id, in sequence order.
  final Map<String, List<Vertex>> verticesByZone;
  final List<MaterialEstimate> materials;
  final List<LineItem> lineItems;

  const EstimateFull({
    required this.estimate,
    required this.zones,
    required this.verticesByZone,
    required this.materials,
    required this.lineItems,
  });

  /// Total price across all line items.
  double get total =>
      lineItems.fold(0.0, (sum, item) => sum + item.extendedAmount);
}

/// An estimate plus its computed total, for list views.
class EstimateListItem {
  final Estimate estimate;
  final double total;

  const EstimateListItem({required this.estimate, required this.total});
}

/// The owner's company identity, printed as the letterhead on estimates.
///
/// Single-row table (`company_profile`, id always 1). Empty fields are
/// omitted from the PDF header.
class CompanyProfile {
  final String businessName;
  final String street;
  final String city;
  final String state;
  final String zip;
  final String phone;
  final String email;

  /// Owner's labor rate in dollars per man-hour; prefilled when adding labor.
  final double laborRate;

  const CompanyProfile({
    this.businessName = '',
    this.street = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.phone = '',
    this.email = '',
    this.laborRate = 0,
  });

  /// "City, ST 12345" — empty when no city/state/zip set.
  String get cityStateZip {
    final parts = <String>[
      city,
      [state, zip].where((s) => s.isNotEmpty).join(' '),
    ].where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  CompanyProfile copyWith({
    String? businessName,
    String? street,
    String? city,
    String? state,
    String? zip,
    String? phone,
    String? email,
    double? laborRate,
  }) {
    return CompanyProfile(
      businessName: businessName ?? this.businessName,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      zip: zip ?? this.zip,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      laborRate: laborRate ?? this.laborRate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'business_name': businessName,
      'street': street,
      'city': city,
      'state': state,
      'zip': zip,
      'phone': phone,
      'email': email,
      'labor_rate': laborRate,
    };
  }

  factory CompanyProfile.fromMap(Map<String, dynamic> map) {
    return CompanyProfile(
      businessName: (map['business_name'] as String?) ?? '',
      street: (map['street'] as String?) ?? '',
      city: (map['city'] as String?) ?? '',
      state: (map['state'] as String?) ?? '',
      zip: (map['zip'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      laborRate: (map['labor_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}
