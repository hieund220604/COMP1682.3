/// Safely parse a numeric value that may be:
///   - A regular [num] (int or double) → convert directly
///   - A [String] → parse with [double.tryParse]
///   - A MongoDB Decimal128 serialized as `{"$numberDecimal": "..."}` Map
///   - null → return [fallback]
///
/// Use this everywhere you read financial amounts from API JSON to avoid
/// [NoSuchMethodError] when the server returns Decimal128 objects.
double safeDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  if (v is Map) {
    // MongoDB Decimal128 wire format: {"$numberDecimal": "100000.00"}
    final dec = v['\$numberDecimal'] ?? v['numberDecimal'];
    if (dec != null) return double.tryParse(dec.toString()) ?? fallback;
  }
  return fallback;
}

/// Same as [safeDouble] but returns null when value is absent/null.
double? safeDoubleOrNull(dynamic v) {
  if (v == null) return null;
  return safeDouble(v);
}
