/// Maps Material Icon names (from seed/backend) to emoji equivalents.
/// Returns null if the icon is already an emoji or not recognized.
String? materialIconToEmoji(String? icon) {
  if (icon == null || icon.isEmpty) return null;

  const map = <String, String>{
    'restaurant': '🍔',
    'directions_car': '🚗',
    'movie': '🍿',
    'receipt_long': '💡',
    'shopping_bag': '🛍️',
    'local_dining': '🍔',
    'fastfood': '🍔',
    'flight': '✈️',
    'hotel': '🏨',
    'school': '📚',
    'medical_services': '💊',
    'card_giftcard': '🎁',
    'sports_esports': '🎮',
    'fitness_center': '💪',
    'pets': '🐾',
    'home': '🏠',
    'build': '🔧',
    'local_gas_station': '⛽',
    'local_hospital': '🏥',
    'local_grocery_store': '🛒',
    'coffee': '☕',
    'music_note': '🎵',
    'phone': '📱',
    'wifi': '📶',
    'power': '💡',
  };

  return map[icon];
}

/// Returns true if the string looks like an emoji (non-ASCII, short).
bool isEmoji(String? s) {
  if (s == null || s.isEmpty) return false;
  // Material icon names are all ASCII; emojis are not
  return s.runes.any((r) => r > 127);
}
