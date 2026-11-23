class Validators {
  Validators._();

  static String? requiredField(String? value, [String message = 'This field is required']) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  static String? positiveNumber(String? value, [String fieldName = 'Value']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final num = double.tryParse(value.trim());
    if (num == null || num <= 0) {
      return 'Please enter a valid positive number';
    }
    return null;
  }

  static String? age(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Age is required';
    }
    final num = int.tryParse(value.trim());
    if (num == null || num < 12 || num > 110) {
      return 'Please enter an age between 12 and 110';
    }
    return null;
  }

  static String? height(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Height is required';
    }
    final num = double.tryParse(value.trim());
    if (num == null || num < 80 || num > 250) {
      return 'Please enter height between 80 and 250 cm';
    }
    return null;
  }

  static String? weight(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Weight is required';
    }
    final num = double.tryParse(value.trim());
    if (num == null || num < 30 || num > 300) {
      return 'Please enter weight between 30 and 300 kg';
    }
    return null;
  }
}
