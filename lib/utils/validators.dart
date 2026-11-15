final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Please enter your email';
  if (!_emailPattern.hasMatch(v)) return 'Please enter a valid email';
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Please enter a password';
  if (v.length < 6) return 'Password must be at least 6 characters';
  return null;
}

String? validateRequired(String? value, {String field = 'This field'}) {
  if (value == null || value.trim().isEmpty) return '$field is required';
  return null;
}

String? validatePhone(String? value) {
  final v = (value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
  if (v.isEmpty) return null; // optional
  if (!RegExp(r'^\+?\d{7,15}$').hasMatch(v)) return 'Please enter a valid phone number';
  return null;
}

String? validatePrice(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Price is required (use 0 for free)';
  final n = double.tryParse(v);
  if (n == null || n < 0) return 'Enter a valid amount';
  return null;
}
