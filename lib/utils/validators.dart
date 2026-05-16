class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }
  
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
  
  static String? validateDisplayName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Display name is required';
    }
    if (value.length < 2) {
      return 'Display name must be at least 2 characters';
    }
    if (value.length > 30) {
      return 'Display name cannot exceed 30 characters';
    }
    return null;
  }
  
  static String? validateBio(String? value) {
    if (value != null && value.length > 500) {
      return 'Bio cannot exceed 500 characters';
    }
    return null;
  }
  
  static String? validateAge(DateTime? birthDate) {
    if (birthDate == null) {
      return 'Birth date is required';
    }
    final age = DateTime.now().difference(birthDate).inDays ~/ 365;
    if (age < 18) {
      return 'You must be at least 18 years old';
    }
    if (age > 100) {
      return 'Please enter a valid birth date';
    }
    return null;
  }
}