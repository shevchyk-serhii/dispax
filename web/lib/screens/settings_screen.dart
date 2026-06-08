import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../modules/core/models/person.dart';
import '../main.dart' show themeModeNotifier, themeFromString;
import 'gdpr_screen.dart';
import 'session_management_screen.dart';
import '../dashboard/driver/earnings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _themeMode = 'system';
  String _language = 'en';
  bool _pushEnabled = true;
  bool _rideUpdates = true;
  bool _chatNotifications = true;
  int _reminderMinutes = 60;
  bool _savingReminder = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = context.read<AuthBloc>().state.user;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _themeMode = prefs.getString('theme_mode') ?? 'system';
      _language = prefs.getString('language') ?? 'en';
      _pushEnabled = prefs.getBool('push_enabled') ?? true;
      _rideUpdates = prefs.getBool('ride_updates') ?? true;
      _chatNotifications = prefs.getBool('chat_notifications') ?? true;
      // Take from the user profile (authoritative source), SharedPreferences as fallback
      _reminderMinutes = user?.reminderMinutes ?? prefs.getInt('reminder_minutes') ?? 60;
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          if (user != null) _buildProfileSection(user),
          if (user?.role == PersonRole.driver) _buildEarningsSection(),
          _buildAccountSection(user),
          _buildNotificationsSection(),
          if (user?.role == PersonRole.driver) _buildReminderSection(),
          _buildAppearanceSection(),
          _buildLanguageSection(),
          _buildSecuritySection(authState),
          _buildPrivacySection(),
          _buildAboutSection(),
          const SizedBox(height: 24),
          _buildLogoutButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildProfileSection(Person user) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _roleGradient(user.role),
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withAlpha(60),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  user.role.name.toUpperCase(),
                  style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () => _showEditProfileDialog(user),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Earnings'),
        ListTile(
          leading: const Icon(Icons.bar_chart_outlined),
          title: const Text('My Earnings'),
          subtitle: const Text('Revenue, expenses and trends'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EarningsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(Person? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Account'),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Change Password'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showChangePasswordDialog(),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Notifications'),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Push Notifications'),
          value: _pushEnabled,
          onChanged: (v) {
            setState(() => _pushEnabled = v);
            _savePreference('push_enabled', v);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.directions_car_outlined),
          title: const Text('Ride Updates'),
          value: _rideUpdates,
          onChanged: (v) {
            setState(() => _rideUpdates = v);
            _savePreference('ride_updates', v);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.chat_outlined),
          title: const Text('Chat Messages'),
          value: _chatNotifications,
          onChanged: (v) {
            setState(() => _chatNotifications = v);
            _savePreference('chat_notifications', v);
          },
        ),
      ],
    );
  }

  Widget _buildReminderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Ride Reminder'),
        ListTile(
          leading: const Icon(Icons.alarm_outlined),
          title: const Text('Remind me before ride'),
          subtitle: const Text('Push notification to leave on time'),
          trailing: _savingReminder
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : DropdownButton<int>(
                  value: _reminderMinutes,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 min')),
                    DropdownMenuItem(value: 30, child: Text('30 min')),
                    DropdownMenuItem(value: 60, child: Text('1 hour')),
                    DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                  ],
                  onChanged: (v) {
                    if (v != null) _saveReminderMinutes(v);
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _saveReminderMinutes(int minutes) async {
    setState(() => _savingReminder = true);
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.put('/users/reminder-minutes', {'minutes': minutes});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('reminder_minutes', minutes);
      if (mounted) setState(() => _reminderMinutes = minutes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  Widget _buildAppearanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Appearance'),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Theme'),
          trailing: DropdownButton<String>(
            value: _themeMode,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'light', child: Text('Light')),
              DropdownMenuItem(value: 'dark', child: Text('Dark')),
              DropdownMenuItem(value: 'system', child: Text('System')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _themeMode = v);
                _savePreference('theme_mode', v);
                themeModeNotifier.value = themeFromString(v);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Language'),
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('Language'),
          trailing: DropdownButton<String>(
            value: _language,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'de', child: Text('Deutsch')),
              DropdownMenuItem(value: 'uk', child: Text('Ukrainian')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _language = v);
                _savePreference('language', v);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection(AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Security'),
        if (authState.biometricAvailable)
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometric Login'),
            value: authState.biometricEnabled,
            onChanged: (v) {
              context.read<AuthBloc>().add(AuthBiometricSetupRequested(
                enabled: v,
                userId: authState.user?.id,
              ));
            },
          ),
        ListTile(
          leading: const Icon(Icons.devices),
          title: const Text('Active Sessions'),
          subtitle: const Text('Manage logged-in devices', style: TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SessionManagementScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Privacy'),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy & Data (GDPR)'),
          subtitle: const Text('Manage consent, export & delete data', style: TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GdprScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('About'),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Version'),
          trailing: Text('1.0.0', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  onPressed: () {
                    Navigator.pop(context);
                    context.read<AuthBloc>().add(const AuthLogoutRequested());
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Logout', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
                validator: (v) {
                  if (v != newCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final authBloc = context.read<AuthBloc>();
                  final apiClient = authBloc.apiClient;
                  await apiClient.put('/users/change-password', {
                    'currentPassword': currentCtrl.text,
                    'newPassword': newCtrl.text,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password changed successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to change password: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(Person user) {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authBloc = context.read<AuthBloc>();
                final apiClient = authBloc.apiClient;
                await apiClient.put('/users/${user.id}', {
                  'name': nameCtrl.text,
                  'phone': phoneCtrl.text,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update profile: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  List<Color> _roleGradient(PersonRole role) {
    switch (role) {
      case PersonRole.driver:
        return AppColors.driverGradient;
      case PersonRole.client:
        return AppColors.clientGradient;
      case PersonRole.secretary:
        return AppColors.secretaryGradient;
      case PersonRole.dispatcher:
        return AppColors.dispatcherGradient;
      case PersonRole.admin:
        return AppColors.dispatcherGradient;
    }
  }
}
