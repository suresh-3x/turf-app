String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter an email';
  }
  // TODO: Add more robust email validation
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a password';
  }
  // TODO: Add password strength validation
  return null;
} 