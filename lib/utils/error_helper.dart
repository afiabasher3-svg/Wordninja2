String friendlyError(String raw) {
  if (raw.contains('Invalid login credentials') ||
      raw.contains('invalid_credentials')) {
    return '❌ Incorrect email or password. Please try again.';
  }
  if (raw.contains('Email not confirmed')) {
    return '📧 Please verify your email before logging in.';
  }
  if (raw.contains('User already registered')) {
    return '⚠️ An account with this email already exists.';
  }
  if (raw.contains('rate limit') || raw.contains('429')) {
    return '⏳ Too many attempts. Please wait a moment and try again.';
  }
  if (raw.contains('network') || raw.contains('timeout')) {
    return '🌐 Network error. Please check your connection.';
  }
  return '⚠️ Something went wrong. Please try again.';
}

bool isValidEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}
