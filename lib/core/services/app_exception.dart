import 'package:supabase_flutter/supabase_flutter.dart';

/// An error with a message that is safe and useful to show to the user.
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Turns any error from Supabase, the network or the AI function into a short,
/// human readable message.
String friendlyError(Object error) {
  if (error is AppException) return error.message;

  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email first (check your inbox for the code).';
    }
    if (msg.contains('user already registered') || msg.contains('already been registered')) {
      return 'An account with this email already exists. Please sign in.';
    }
    if (msg.contains('token has expired') || (msg.contains('otp') && msg.contains('expired'))) {
      return 'This code has expired. Request a new one.';
    }
    if (msg.contains('invalid') && (msg.contains('token') || msg.contains('otp'))) {
      return 'This code is not valid. Check it and try again.';
    }
    if (msg.contains('rate limit') || error.statusCode == '429') {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (msg.contains('password') && msg.contains('at least')) {
      return error.message;
    }
    if (msg.contains('same password') || msg.contains('different from the old')) {
      return 'Choose a password that is different from your current one.';
    }
    if (msg.contains('signups not allowed') || msg.contains('signup is disabled')) {
      return 'New sign-ups are currently closed.';
    }
    return error.message;
  }

  if (error is FunctionException) {
    final details = error.details;
    if (details is Map && details['message'] is String) {
      return details['message'] as String;
    }
    if (error.status == 401) return 'Your session expired. Please sign in again.';
    if (error.status == 403) return 'Your account is not approved yet.';
    if (error.status == 404) {
      return 'The AI service is not set up yet (Edge Function "analyze-food" not found).';
    }
    return 'The AI service returned an error (${error.status}). Please try again.';
  }

  if (error is PostgrestException) {
    if (error.code == '42501' || error.message.contains('row-level security')) {
      return 'You do not have access to this. Your account may not be approved.';
    }
    if (error.code == 'PGRST301' || error.message.toLowerCase().contains('jwt')) {
      return 'Your session expired. Please sign in again.';
    }
    if (error.code == '23514') return 'One of the values is out of the allowed range.';
    return error.message;
  }

  if (error is StorageException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('row-level security') || error.statusCode == '403') {
      return 'Photo upload is not allowed for this account yet.';
    }
    if (msg.contains('too large') || error.statusCode == '413') {
      return 'This photo is too large. Please choose a smaller one.';
    }
    if (msg.contains('mime')) return 'Please use a JPG, PNG or WebP photo.';
    return error.message;
  }

  final text = error.toString();
  final lower = text.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('clientexception') ||
      lower.contains('xmlhttprequest error') ||
      lower.contains('failed to fetch') ||
      lower.contains('network')) {
    return 'No internet connection. Check your connection and try again.';
  }
  if (lower.contains('timeout')) return 'The server took too long to answer. Please try again.';
  return text.replaceFirst('Exception: ', '');
}
