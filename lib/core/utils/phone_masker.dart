/// Reusable utility to mask phone numbers for restricted roles (e.g. `viewer`).
///
/// Requirement:
/// "viewer: no action buttons anywhere, masked phone numbers, but KPIs and trips are visible."
class PhoneMasker {
  PhoneMasker._();

  /// Masks middle digits of a phone number if [shouldMask] is true.
  /// Example: `+97455123456` -> `+974 55•• ••56`
  static String mask(String? phone, {required bool shouldMask}) {
    if (phone == null || phone.isEmpty) return '—';
    if (!shouldMask) return phone;

    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length <= 4) return '••••';

    // Keep prefix (e.g. +974 or first 4 chars) and last 2 digits, mask the rest
    final prefixLen = cleaned.startsWith('+') ? 4 : 2;
    if (cleaned.length <= prefixLen + 2) {
      return '${cleaned.substring(0, prefixLen)} ••••';
    }

    final prefix = cleaned.substring(0, prefixLen);
    final suffix = cleaned.substring(cleaned.length - 2);
    return '$prefix •••• ••$suffix';
  }
}
