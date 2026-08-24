import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/data/auth_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: ListView(
        children: [
          _SectionHeader('Account'),
          if (user != null) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(user.displayName),
              subtitle: Text(user.email),
            ),
          ],
          const Divider(height: 1),
          _SectionHeader('Payment'),
          ListTile(
            leading: const Icon(
              Icons.credit_card_rounded,
              color: AppColors.primary,
            ),
            title: const Text(AppStrings.paymentMethod),
            subtitle: Text(
              user?.hasPaymentMethod == true
                  ? 'Card on file'
                  : AppStrings.noPaymentMethod,
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textDisabled,
            ),
            onTap: () => context.push('/settings/payment'),
          ),
          const Divider(height: 1),
          _SectionHeader('Preferences'),
          _ToggleTile(
            icon: Icons.notifications_outlined,
            label: AppStrings.notifications,
            value: user?.notificationsEnabled ?? true,
            onChanged: (v) =>
                _updatePref(ref, user?.uid, 'notifications_enabled', v),
          ),
          _ToggleTile(
            icon: Icons.volume_up_outlined,
            label: AppStrings.sound,
            value: user?.soundEnabled ?? true,
            onChanged: (v) => _updatePref(ref, user?.uid, 'sound_enabled', v),
          ),
          _ToggleTile(
            icon: Icons.vibration_rounded,
            label: AppStrings.haptics,
            value: user?.hapticsEnabled ?? true,
            onChanged: (v) => _updatePref(ref, user?.uid, 'haptics_enabled', v),
          ),
          const Divider(height: 1),
          _SectionHeader('About'),
          ListTile(
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text(
                  'YD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            title: const Text('You-Do'),
            subtitle: const Text('Version 1.0.0'),
          ),
          const Gap(AppSizes.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
            child: OutlinedButton.icon(
              onPressed: () => _signOut(context, ref),
              icon: const Icon(Icons.logout_rounded, color: AppColors.penalty),
              label: Text(
                AppStrings.signOut,
                style: const TextStyle(color: AppColors.penalty),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.penalty),
              ),
            ),
          ),
          const Gap(AppSizes.xl),
        ],
      ),
    );
  }

  Future<void> _updatePref(
    WidgetRef ref,
    String? uid,
    String field,
    bool value,
  ) async {
    if (uid == null) return;
    await ref.read(authRepositoryProvider).updateUserField(uid, {field: value});
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.signOut),
        content: const Text(AppStrings.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              AppStrings.signOut,
              style: TextStyle(color: AppColors.penalty),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.md,
        AppSizes.md,
        AppSizes.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.primary),
      title: Text(label),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }
}
