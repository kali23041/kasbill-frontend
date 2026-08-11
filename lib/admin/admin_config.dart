/// Optional email allowlist for Admin UI (lowercased).
/// Prefer setting `role: Admin` on the Firestore user doc.
class AdminConfig {
  static const Set<String> allowlistEmails = {
    // e.g. 'you@example.com',
  };

  static bool isAllowlisted(String? email) {
    final id = email?.trim().toLowerCase();
    if (id == null || id.isEmpty) return false;
    return allowlistEmails.contains(id);
  }
}
