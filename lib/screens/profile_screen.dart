import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'You can sign back in anytime with your email and password.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
            'This permanently deletes your profile, meters, readings and bills. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AuthService.instance.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = error.code == 'requires-recent-login'
          ? 'For security, please log in again before deleting your account.'
          : AuthService.messageFor(error);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showPersonalDetails() {
    final user = FirebaseAuth.instance.currentUser;
    final nameCtrl = TextEditingController(text: user?.displayName ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text('Personal Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Update your profile information below.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 24),
              const Text('DISPLAY NAME',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  hintText: 'Enter your name',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    setState(() => _busy = true);
                    try {
                      await AuthService.instance
                          .updateProfileName(nameCtrl.text);
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Profile updated successfully!'),
                          backgroundColor: AppColors.accentGreen));
                    } catch (e) {
                      messenger.showSnackBar(
                          SnackBar(content: Text('Update failed: $e')));
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSecuritySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Security & Privacy',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _actionTile(Icons.mail_outline_rounded, 'Change Password',
                'Send password reset link to your email', () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              setState(() => _busy = true);
              try {
                await AuthService.instance.sendPasswordReset();
                messenger.showSnackBar(const SnackBar(
                    content: Text('Password reset email sent!'),
                    backgroundColor: AppColors.primary));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            }),
            _actionTile(Icons.delete_forever_outlined, 'Delete Account',
                'Permanently remove your account and data', () {
              Navigator.pop(ctx);
              _deleteAccount();
            }, color: AppColors.accentRed),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
      IconData icon, String title, String sub, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: (color ?? AppColors.primary).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color ?? AppColors.primary, size: 22),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15, color: color)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    );
  }

  void _showNotificationSettings() {
    bool billReminders = true;
    bool highUsage = true;
    String frequency = 'Daily';
    TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Usage Notifications',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Set reminders to check your meter readings.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 24),

              const Text('REMINDER SETTINGS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1)),
              const SizedBox(height: 12),

              // Frequency Selector
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: ['Daily', 'Weekly'].map((f) {
                    final selected = frequency == f;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setMState(() => frequency = f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            f,
                            style: TextStyle(
                              color: selected ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Time Picker Tile
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                tileColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.access_time_rounded, color: AppColors.primary),
                title: const Text('Reminder Time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: Text(
                  reminderTime.format(ctx),
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 16),
                ),
                onTap: () async {
                  final picked = await showTimePicker(context: ctx, initialTime: reminderTime);
                  if (picked != null) setMState(() => reminderTime = picked);
                },
              ),
              const SizedBox(height: 24),

              const Text('SYSTEM ALERTS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1)),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bill Reminders',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Get notified when your bill is estimated.',
                    style: TextStyle(fontSize: 11)),
                value: billReminders,
                onChanged: (v) => setMState(() => billReminders = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('High Usage Alert',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Notify if daily units exceed 20 kWh.',
                    style: TextStyle(fontSize: 11)),
                value: highUsage,
                onChanged: (v) => setMState(() => highUsage = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reminders set for $frequency at ${reminderTime.format(context)}. Message: "Check reading"')),
                    );
                  },
                  child: const Text('Save Notification Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaxGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tax & Tariff Guide',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Understanding how your FESCO bill is calculated.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _guideItem(
                    Icons.shield_outlined,
                    'Protected Category',
                    'Users consuming less than 200 units for 6 consecutive months fall into the Protected category, enjoying significantly lower rates.',
                  ),
                  _guideItem(
                    Icons.layers_outlined,
                    'Tariff Slabs',
                    'Rates increase as you consume more. The first 100 units are cheapest, while units above 700 are the most expensive.',
                  ),
                  _guideItem(
                    Icons.account_balance_outlined,
                    'Government Taxes',
                    'Your bill includes GST (18.71%), Electricity Duty, FC Surcharge, and FPA (Fuel Price Adjustment).',
                  ),
                  _guideItem(
                    Icons.tv_outlined,
                    'Fixed Charges',
                    'A small fixed amount (Rs 35) is added as PTV License Fee along with standard service charges.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guideItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutApp() {
    showAboutDialog(
      context: context,
      applicationName: 'MeterPro',
      applicationVersion: '1.2.0',
      applicationIcon: const Icon(Icons.bolt_rounded,
          color: AppColors.accentOrange, size: 42),
      children: [
        const Text(
            'MeterPro is a smart electricity management tool designed for FESCO consumers to scan, track, and estimate their monthly bills using advanced AI technology.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email?.split('@').first ?? 'Account');
    final email = user?.email ?? '';
    final initials = displayName.trim().isEmpty
        ? '?'
        : displayName
            .trim()
            .split(RegExp(r'\s+'))
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
                  decoration: const BoxDecoration(
                    gradient: AppColors.headerGradient,
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(32)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          child: Text(
                            initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const Text(
                      'ACCOUNT SETTINGS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 12),
                    _crystalTile(Icons.person_outline_rounded,
                        'Personal Details', _showPersonalDetails),
                    _crystalTile(Icons.lock_outline_rounded,
                        'Security & Privacy', _showSecuritySettings),
                    _crystalTile(Icons.notifications_none_rounded,
                        'Usage Notifications', _showNotificationSettings),
                    const SizedBox(height: 28),
                    const Text(
                      'RESOURCES & INFO',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 12),
                    _crystalTile(Icons.menu_book_outlined, 'Tax & Tariff Guide',
                        _showTaxGuide),
                    _crystalTile(
                        Icons.help_outline_rounded,
                        'Help & Support',
                        () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Support email: support@meterunit.app')))),
                    _crystalTile(Icons.info_outline_rounded, 'About MeterPro',
                        _showAboutApp),
                    const SizedBox(height: 32),
                    InkWell(
                      onTap: _logout,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.accentRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  AppColors.accentRed.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded,
                                color: AppColors.accentRed, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Log Out',
                              style: TextStyle(
                                  color: AppColors.accentRed,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black26,
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _crystalTile(IconData icon, String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textPrimary),
        ),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textMuted, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
