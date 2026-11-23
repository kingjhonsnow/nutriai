import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:nutri_ai/core/services/account_repository.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/services/preferences_service.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/data/models/account_info.dart';
import 'package:nutri_ai/data/models/fitness_goal.dart';
import 'package:nutri_ai/data/models/user_profile.dart';

enum AuthStatus { initializing, signedOut, signedIn }

enum RegisterOutcome { failed, signedIn, needsEmailCode }

class AuthState {
  final AuthStatus status;
  final bool isLoading;
  final String? errorMessage;
  final String? userId;
  final String? userEmail;
  final AccountInfo? account;
  final UserProfile? bodyProfile;
  final FitnessGoal? goal;

  /// The user opened a password reset link and must now choose a new password.
  final bool passwordRecovery;

  /// A reset code is being verified; keeps the router on the reset screen.
  final bool isRecoveringWithCode;

  /// Email waiting for its confirmation code (when email confirmation is on).
  final String? pendingVerificationEmail;

  const AuthState({
    this.status = AuthStatus.initializing,
    this.isLoading = false,
    this.errorMessage,
    this.userId,
    this.userEmail,
    this.account,
    this.bodyProfile,
    this.goal,
    this.passwordRecovery = false,
    this.isRecoveringWithCode = false,
    this.pendingVerificationEmail,
  });

  bool get isAuthenticated => status == AuthStatus.signedIn;
  bool get isApproved => account?.hasAccess ?? false;
  bool get isAdmin => account?.isAdmin ?? false;
  String? get userName => account?.fullName;
  String? get avatarUrl => account?.avatarUrl;

  /// Changes only when the user or their access changes. Data providers watch
  /// this so they reload for a new user and never show another user's data.
  String? get sessionKey => userId == null ? null : '$userId|${isApproved ? 1 : 0}';

  /// Note: errorMessage is always replaced (pass it again to keep it).
  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    String? errorMessage,
    String? userId,
    String? userEmail,
    AccountInfo? account,
    UserProfile? bodyProfile,
    FitnessGoal? goal,
    bool? passwordRecovery,
    bool? isRecoveringWithCode,
    String? pendingVerificationEmail,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      account: account ?? this.account,
      bodyProfile: bodyProfile ?? this.bodyProfile,
      goal: goal ?? this.goal,
      passwordRecovery: passwordRecovery ?? this.passwordRecovery,
      isRecoveringWithCode: isRecoveringWithCode ?? this.isRecoveringWithCode,
      pendingVerificationEmail: pendingVerificationEmail ?? this.pendingVerificationEmail,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  StreamSubscription<sb.AuthState>? _authSub;

  String? _loadedFor;
  Future<void>? _inflight;
  String? _inflightFor;
  int _loadSeq = 0;
  bool _recovering = false;

  AuthNotifier(this._ref) : super(const AuthState()) {
    _start();
  }

  sb.SupabaseClient get _client => _ref.read(supabaseClientProvider);
  AccountRepository get _repo => _ref.read(accountRepositoryProvider);
  PreferencesService get _prefs => _ref.read(preferencesServiceProvider);

  String? get _webRedirect => kIsWeb ? Uri.base.origin : null;

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  void _start() {
    final session = _client.auth.currentSession;
    if (session == null) {
      state = const AuthState(status: AuthStatus.signedOut);
    } else {
      _loadUser(session.user);
    }
    _authSub = _client.auth.onAuthStateChange.listen(
      _onAuthEvent,
      onError: (Object e) => debugPrint('[Auth] stream error: $e'),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _onAuthEvent(sb.AuthState data) async {
    final event = data.event;
    final session = data.session;

    if (event == sb.AuthChangeEvent.signedOut) {
      _loadedFor = null;
      _loadSeq++;
      if (mounted) state = const AuthState(status: AuthStatus.signedOut);
      return;
    }

    if (event == sb.AuthChangeEvent.passwordRecovery) {
      if (session != null) {
        await _loadUser(session.user);
        if (mounted) state = state.copyWith(passwordRecovery: true);
      }
      return;
    }

    if (session == null) {
      if (mounted && state.status == AuthStatus.initializing) {
        state = const AuthState(status: AuthStatus.signedOut);
      }
      return;
    }

    if (_loadedFor != session.user.id) {
      await _loadUser(session.user);
    }
  }

  Future<void> _loadUser(sb.User user) {
    final running = _inflight;
    if (running != null && _inflightFor == user.id) return running;
    _inflightFor = user.id;
    final future = _doLoad(user).whenComplete(() {
      if (_inflightFor == user.id) {
        _inflight = null;
        _inflightFor = null;
      }
    });
    _inflight = future;
    return future;
  }

  Future<void> _doLoad(sb.User user) async {
    final seq = ++_loadSeq;
    try {
      final data = await _repo.loadSession(user);
      if (!mounted || seq != _loadSeq) return;
      _loadedFor = user.id;
      state = AuthState(
        status: AuthStatus.signedIn,
        userId: user.id,
        userEmail: user.email,
        account: data.account,
        bodyProfile: data.bodyProfile,
        goal: data.goal,
        passwordRecovery: state.passwordRecovery,
        isRecoveringWithCode: _recovering,
      );
      if (data.account.hasAccess) {
        unawaited(_uploadPendingAvatar());
      }
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      debugPrint('[Auth] could not load account: $e');
      // Signed in, but the account could not be loaded (offline, ...). The
      // router shows the access screen with this error and a Retry button.
      state = AuthState(
        status: AuthStatus.signedIn,
        userId: user.id,
        userEmail: user.email,
        errorMessage: friendlyError(e),
        isRecoveringWithCode: _recovering,
      );
    }
  }

  /// Reloads the account (used by "Check again" on the waiting screen).
  Future<void> refreshAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    state = state.copyWith(isLoading: true);
    _inflight = null;
    _inflightFor = null;
    await _loadUser(user);
    if (mounted) state = state.copyWith(isLoading: false, errorMessage: state.errorMessage);
  }

  // ---------------------------------------------------------------------------
  // Sign in / sign up
  // ---------------------------------------------------------------------------

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _client.auth.signInWithPassword(email: email.trim(), password: password);
      final user = res.user;
      if (user == null) throw const AppException('Sign in failed. Please try again.');
      await _loadUser(user);
      if (mounted) state = state.copyWith(isLoading: false, errorMessage: state.errorMessage);
      return true;
    } catch (e) {
      final notConfirmed = e is sb.AuthException && e.message.toLowerCase().contains('not confirmed');
      state = AuthState(
        status: AuthStatus.signedOut,
        errorMessage: friendlyError(e),
        pendingVerificationEmail: notConfirmed ? email.trim() : null,
      );
      return false;
    }
  }

  Future<RegisterOutcome> register({
    required String name,
    required String email,
    required String password,
    Uint8List? avatarBytes,
  }) async {
    state = state.copyWith(isLoading: true);
    final cleanEmail = email.trim();
    try {
      final res = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'full_name': name.trim()},
        emailRedirectTo: _webRedirect,
      );
      if (avatarBytes != null) {
        await _prefs.savePendingAvatar(cleanEmail, avatarBytes);
      }
      if (res.session == null) {
        // Email confirmation is switched on in Supabase: a code was emailed.
        state = AuthState(status: AuthStatus.signedOut, pendingVerificationEmail: cleanEmail);
        return RegisterOutcome.needsEmailCode;
      }
      await _loadUser(res.session!.user);
      if (mounted) state = state.copyWith(isLoading: false, errorMessage: state.errorMessage);
      return RegisterOutcome.signedIn;
    } catch (e) {
      state = AuthState(status: AuthStatus.signedOut, errorMessage: friendlyError(e));
      return RegisterOutcome.failed;
    }
  }

  Future<bool> verifySignupCode(String email, String code) async {
    state = state.copyWith(isLoading: true, pendingVerificationEmail: email);
    try {
      sb.AuthResponse res;
      try {
        res = await _client.auth.verifyOTP(type: sb.OtpType.signup, email: email.trim(), token: code.trim());
      } on sb.AuthException {
        // Newer Supabase projects verify sign-up codes with the "email" type.
        res = await _client.auth.verifyOTP(type: sb.OtpType.email, email: email.trim(), token: code.trim());
      }
      final user = res.user ?? _client.auth.currentUser;
      if (user == null) throw const AppException('The code could not be verified. Please try again.');
      await _loadUser(user);
      if (mounted) state = state.copyWith(isLoading: false, errorMessage: state.errorMessage);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
      return false;
    }
  }

  Future<bool> resendSignupCode(String email) async {
    state = state.copyWith(isLoading: true);
    try {
      await _client.auth.resend(type: sb.OtpType.signup, email: email.trim(), emailRedirectTo: _webRedirect);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Password reset
  // ---------------------------------------------------------------------------

  Future<bool> sendPasswordResetCode(String email) async {
    state = state.copyWith(isLoading: true);
    try {
      await _client.auth.resetPasswordForEmail(email.trim(), redirectTo: _webRedirect);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
      return false;
    }
  }

  /// Verifies the 6-digit reset code from the email and sets the new password.
  Future<bool> resetPasswordWithCode(String email, String code, String newPassword) async {
    _recovering = true;
    state = state.copyWith(isLoading: true, isRecoveringWithCode: true);
    var codeAccepted = false;
    try {
      await _client.auth.verifyOTP(type: sb.OtpType.recovery, email: email.trim(), token: code.trim());
      codeAccepted = true;
      await _client.auth.updateUser(sb.UserAttributes(password: newPassword));
      _recovering = false;
      final user = _client.auth.currentUser;
      if (user != null) {
        _inflight = null;
        _inflightFor = null;
        await _loadUser(user);
      }
      if (mounted) {
        state = state.copyWith(isLoading: false, isRecoveringWithCode: false, passwordRecovery: false);
      }
      return true;
    } catch (e) {
      _recovering = false;
      final message = friendlyError(e);
      if (codeAccepted) {
        // The code worked but the password was refused: sign out again so the
        // user is not left half-way.
        try {
          await _client.auth.signOut();
        } catch (_) {}
      }
      state = AuthState(status: AuthStatus.signedOut, errorMessage: message);
      return false;
    }
  }

  /// Used after opening a password reset LINK (instead of a code).
  Future<bool> setNewPassword(String newPassword) async {
    state = state.copyWith(isLoading: true);
    try {
      await _client.auth.updateUser(sb.UserAttributes(password: newPassword));
      state = state.copyWith(isLoading: false, passwordRecovery: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Profile photo
  // ---------------------------------------------------------------------------

  /// Returns null on success, otherwise an error message for the user.
  Future<String?> updateProfilePhoto(Uint8List bytes) async {
    final userId = state.userId;
    final account = state.account;
    if (userId == null || account == null) return 'Please sign in again.';
    if (!account.hasAccess) return 'You can add a photo once your account is approved.';
    try {
      final path = await _repo.uploadAvatar(userId, bytes, oldPath: account.avatarPath);
      if (mounted) {
        state = state.copyWith(
          account: account.copyWith(avatarPath: path, avatarUrl: _repo.avatarUrlFor(path)),
        );
      }
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  Future<String?> removeProfilePhoto() async {
    final userId = state.userId;
    final account = state.account;
    if (userId == null || account == null) return 'Please sign in again.';
    try {
      await _repo.removeAvatar(userId, account.avatarPath);
      if (mounted) state = state.copyWith(account: account.copyWith(clearAvatar: true));
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  Future<void> _uploadPendingAvatar() async {
    final email = state.userEmail;
    if (email == null) return;
    final bytes = _prefs.getPendingAvatar(email);
    if (bytes == null) return;
    if (state.account?.avatarPath != null) {
      await _prefs.clearPendingAvatar(email);
      return;
    }
    final error = await updateProfilePhoto(bytes);
    if (error == null) {
      await _prefs.clearPendingAvatar(email);
    } else {
      debugPrint('[Auth] pending avatar upload failed: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // Cached copies (kept in sync by the profile and goal providers)
  // ---------------------------------------------------------------------------

  void cacheBodyProfile(UserProfile profile) {
    final account = state.account;
    state = state.copyWith(
      bodyProfile: profile,
      account: account?.copyWith(fullName: profile.name),
    );
  }

  void cacheGoal(FitnessGoal goal) {
    state = state.copyWith(goal: goal);
  }

  // ---------------------------------------------------------------------------
  // Sign out / delete account
  // ---------------------------------------------------------------------------

  Future<void> logout() async {
    _loadSeq++;
    _loadedFor = null;
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('[Auth] sign out error (local session cleared anyway): $e');
    }
    if (mounted) state = const AuthState(status: AuthStatus.signedOut);
  }

  /// Deletes the account and all its data. Returns null on success.
  Future<String?> deleteAccount() async {
    try {
      await _repo.deleteMyAccount(avatarPath: state.account?.avatarPath);
    } catch (e) {
      return friendlyError(e);
    }
    final email = state.userEmail;
    if (email != null) await _prefs.clearPendingAvatar(email);
    await logout();
    return null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
