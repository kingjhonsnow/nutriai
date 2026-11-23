import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/data/models/account_info.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';

class AdminState {
  final List<AccountInfo> accounts;
  final bool isLoading;
  final String? errorMessage;

  const AdminState({this.accounts = const [], this.isLoading = false, this.errorMessage});

  List<AccountInfo> get pending => accounts.where((a) => a.status == AccountStatus.pending && !a.isAdmin).toList();
  List<AccountInfo> get active => accounts.where((a) => a.hasAccess).toList();
  List<AccountInfo> get blocked => accounts
      .where((a) => !a.isAdmin && (a.status == AccountStatus.rejected || a.status == AccountStatus.revoked || (a.status == AccountStatus.approved && a.isExpired)))
      .toList();
}

class AdminNotifier extends StateNotifier<AdminState> {
  final Ref _ref;

  AdminNotifier(this._ref) : super(const AdminState()) {
    if (_ref.read(authProvider).isAdmin) load();
  }

  Future<void> load() async {
    state = AdminState(accounts: state.accounts, isLoading: true);
    try {
      final accounts = await _ref.read(accountRepositoryProvider).adminListAccounts();
      if (!mounted) return;
      state = AdminState(accounts: accounts);
    } catch (e) {
      if (!mounted) return;
      state = AdminState(accounts: state.accounts, errorMessage: friendlyError(e));
    }
  }

  /// Each action returns null on success or an error message.
  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      await load();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  Future<String?> approve(String userId, {DateTime? until}) => _run(
      () => _ref.read(accountRepositoryProvider).adminSetAccess(userId, AccountStatus.approved, accessUntil: until));

  Future<String?> reject(String userId) =>
      _run(() => _ref.read(accountRepositoryProvider).adminSetAccess(userId, AccountStatus.rejected));

  Future<String?> revoke(String userId) =>
      _run(() => _ref.read(accountRepositoryProvider).adminSetAccess(userId, AccountStatus.revoked));

  Future<String?> setTemporaryPassword(String userId, String password) =>
      _run(() => _ref.read(accountRepositoryProvider).adminSetPassword(userId, password));

  Future<String?> deleteUser(String userId) =>
      _run(() => _ref.read(accountRepositoryProvider).adminDeleteUser(userId));
}

final adminProvider = StateNotifierProvider.autoDispose<AdminNotifier, AdminState>((ref) {
  ref.watch(authProvider.select((s) => s.sessionKey));
  return AdminNotifier(ref);
});
