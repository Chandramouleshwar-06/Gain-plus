import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui.dart';
import 'account_provider.dart';
import 'sign_in_screen.dart';

/// Account status on the Profile tab: sign in, sync state, sign out.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    if (!account.available) return const SizedBox.shrink();

    if (!account.signedIn) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: AppColors.textMuted),
                SizedBox(width: 10),
                Expanded(child: Text('Not backed up', style: AppText.strong)),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Sign in to back up your training and use it on any phone.', style: AppText.muted),
            const SizedBox(height: 14),
            PrimaryButton(
              text: 'Sign in',
              icon: Icons.cloud_upload_rounded,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
            ),
          ],
        ),
      );
    }

    final user = account.user!;
    final status = account.syncing
        ? 'Syncing…'
        : account.lastError ?? (account.lastSyncedAt == null ? 'Not synced yet' : 'Synced ${_ago(account.lastSyncedAt!)}');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                account.lastError != null ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                color: account.lastError != null ? AppColors.orange : AppColors.lime,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.email ?? user.displayName ?? 'Signed in', style: AppText.strong),
                    Text(status,
                        style: AppText.muted.copyWith(color: account.lastError != null ? AppColors.orange : null)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sync now',
                onPressed: account.syncing ? null : account.syncNow,
                icon: account.syncing
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime))
                    : const Icon(Icons.sync_rounded, color: AppColors.text),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: account.syncing ? null : () => _signOut(context, account),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Sign out'),
              ),
              TextButton(
                onPressed: account.syncing ? null : () => _deleteAccount(context, account),
                style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                child: const Text('Delete account'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  Future<void> _signOut(BuildContext context, AccountProvider account) async {
    final ok = await confirmDialog(
      context,
      title: 'Sign out?',
      message: 'Your data is uploaded first, then removed from this phone. Sign in again to get it all back. '
          "Progress photos aren't uploaded, so they'll be deleted.",
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await account.signOut();
    } on UnsyncedChangesError catch (e) {
      if (!context.mounted) return;
      final discard = await confirmDialog(
        context,
        title: "Couldn't upload",
        message: '${e.pending} changes are not backed up yet (you seem to be offline). '
            'Sign out anyway and lose them, or stay signed in and try again later.',
        confirmLabel: 'Sign out anyway',
        cancelLabel: 'Stay signed in',
        destructive: true,
      );
      if (discard) await account.signOut(discardUnsynced: true);
    }
  }

  Future<void> _deleteAccount(BuildContext context, AccountProvider account) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Delete your account?',
      message: 'This permanently deletes your account and everything backed up with it, '
          "and removes your data from this phone. It can't be undone.",
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!ok) return;
    try {
      await account.deleteAccount();
      messenger.showSnackBar(const SnackBar(content: Text('Your account and data were deleted.')));
    } on AccountError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint('Delete account failed: $e');
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't delete your account. Check your connection and try again.")));
    }
  }
}
