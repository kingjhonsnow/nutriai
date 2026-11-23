import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/data/models/account_info.dart';
import 'package:nutri_ai/features/admin/providers/admin_provider.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';

/// Admin panel: approve or block access, set an access end date, give a
/// temporary password, delete users. Only reachable for the admin account;
/// the database also rejects these actions for anyone else.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  int _tab = 0; // 0 waiting, 1 active, 2 blocked, 3 all
  final _dateFormat = DateFormat('d MMM yyyy');

  void _snack(String? error, String success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? success),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
    ));
  }

  Future<void> _approveUntil(AccountInfo a) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      helpText: 'Access ends on',
    );
    if (picked == null) return;
    final until = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
    final err = await ref.read(adminProvider.notifier).approve(a.id, until: until);
    _snack(err, '${a.fullName} approved until ${_dateFormat.format(until)}');
  }

  Future<void> _setPassword(AccountInfo a) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Temporary password for ${a.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Give this password to the person. They can sign in with it and change it later '
                'with "Forgot password".'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'New password (min. 8 characters)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Set password'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (password == null || password.isEmpty) return;
    if (password.length < 8) {
      _snack('The password must have at least 8 characters.', '');
      return;
    }
    final err = await ref.read(adminProvider.notifier).setTemporaryPassword(a.id, password);
    _snack(err, 'Temporary password set for ${a.fullName}');
  }

  Future<void> _delete(AccountInfo a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete user?'),
        content: Text('This permanently deletes ${a.fullName} (${a.email}) and all their data. '
            'This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await ref.read(adminProvider.notifier).deleteUser(a.id);
    _snack(err, '${a.fullName} deleted');
  }

  void _showActions(AccountInfo a) {
    final notifier = ref.read(adminProvider.notifier);
    final isSelf = a.id == ref.read(authProvider).userId;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(a.fullName, style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text(a.email),
              ),
              const Divider(height: 1),
              if (isSelf)
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('This is your own admin account.'),
                )
              else ...[
                ListTile(
                  leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                  title: const Text('Approve (no end date)'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final err = await notifier.approve(a.id);
                    _snack(err, '${a.fullName} approved');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_available_rounded, color: AppColors.accent),
                  title: const Text('Approve until a date...'),
                  subtitle: const Text('For example for a monthly subscription'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _approveUntil(a);
                  },
                ),
                if (a.status == AccountStatus.approved)
                  ListTile(
                    leading: const Icon(Icons.block_rounded, color: AppColors.warning),
                    title: const Text('Revoke access'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final err = await notifier.revoke(a.id);
                      _snack(err, 'Access revoked for ${a.fullName}');
                    },
                  ),
                if (a.status == AccountStatus.pending)
                  ListTile(
                    leading: const Icon(Icons.cancel_rounded, color: AppColors.error),
                    title: const Text('Reject'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final err = await notifier.reject(a.id);
                      _snack(err, '${a.fullName} rejected');
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.key_rounded, color: Colors.amber),
                  title: const Text('Set a temporary password'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _setPassword(a);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                  title: const Text('Delete user and all data', style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _delete(a);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(AccountInfo a) {
    late final String label;
    late final Color color;
    if (a.isAdmin) {
      label = 'ADMIN';
      color = AppColors.accent;
    } else if (a.status == AccountStatus.approved && a.isExpired) {
      label = 'EXPIRED';
      color = AppColors.warning;
    } else {
      switch (a.status) {
        case AccountStatus.pending:
          label = 'WAITING';
          color = Colors.amber;
          break;
        case AccountStatus.approved:
          label = 'ACTIVE';
          color = AppColors.success;
          break;
        case AccountStatus.rejected:
          label = 'REJECTED';
          color = AppColors.error;
          break;
        case AccountStatus.revoked:
          label = 'REVOKED';
          color = AppColors.error;
          break;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }

  Widget _tile(AccountInfo a) {
    final notifier = ref.read(adminProvider.notifier);
    final subtitleParts = <String>[a.email];
    if (a.createdAt != null) subtitleParts.add('joined ${_dateFormat.format(a.createdAt!)}');
    if (a.accessUntil != null) subtitleParts.add('access until ${_dateFormat.format(a.accessUntil!)}');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => _showActions(a),
            leading: CircleAvatar(
              backgroundColor: AppColors.surfaceLight,
              backgroundImage: a.avatarUrl != null ? NetworkImage(a.avatarUrl!) : null,
              child: a.avatarUrl == null ? const Icon(Icons.person, color: AppColors.primary) : null,
            ),
            title: Row(
              children: [
                Flexible(child: Text(a.fullName, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                _statusChip(a),
              ],
            ),
            subtitle: Text(subtitleParts.join(' · '), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            trailing: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary),
          ),
          if (a.status == AccountStatus.pending && !a.isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final err = await notifier.reject(a.id);
                        _snack(err, '${a.fullName} rejected');
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final err = await notifier.approve(a.id);
                        _snack(err, '${a.fullName} approved');
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(adminProvider);
    final lists = [admin.pending, admin.active, admin.blocked, admin.accounts];
    final labels = ['Waiting (${admin.pending.length})', 'Active (${admin.active.length})', 'Blocked (${admin.blocked.length})', 'All (${admin.accounts.length})'];
    final visible = lists[_tab];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Admin: Access'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(adminProvider.notifier).load(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(adminProvider.notifier).load(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(labels.length, (i) {
                  return ChoiceChip(
                    label: Text(labels[i]),
                    selected: _tab == i,
                    onSelected: (_) => setState(() => _tab = i),
                    selectedColor: AppColors.primary.withOpacity(0.25),
                  );
                }),
              ),
              const SizedBox(height: 16),
              if (admin.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(admin.errorMessage!, style: const TextStyle(color: AppColors.error)),
                ),
              if (admin.isLoading && admin.accounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      _tab == 0 ? 'Nobody is waiting for approval.' : 'No accounts here.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...visible.map(_tile),
              const SizedBox(height: 12),
              Text(
                'Share your app link with people. They create an account and appear under "Waiting". '
                'Nobody can use the app until you approve them.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
