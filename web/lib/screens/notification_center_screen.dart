import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';

class _Notification {
  final String id;
  final String title;
  final String body;
  final String notificationType;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  const _Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.notificationType,
    required this.createdAt,
    required this.isRead,
    this.data,
  });

  factory _Notification.fromJson(Map<String, dynamic> json) {
    return _Notification(
      id: json['id']?['value'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      notificationType: json['notificationType'] ?? '',
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isRead: json['isRead'] ?? false,
      data: json['data'] != null
          ? (json['data'] is String ? jsonDecode(json['data']) : json['data'])
          : null,
    );
  }
}

class _NotifPrefs {
  bool rideUpdates;
  bool chatMessages;
  bool driverApproaching;
  bool geofenceAlerts;
  bool poolUpdates;
  bool emailNotifications;
  bool smsNotifications;
  String? quietHoursStart;
  String? quietHoursEnd;

  _NotifPrefs({
    this.rideUpdates = true,
    this.chatMessages = true,
    this.driverApproaching = true,
    this.geofenceAlerts = true,
    this.poolUpdates = true,
    this.emailNotifications = false,
    this.smsNotifications = false,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  factory _NotifPrefs.fromJson(Map<String, dynamic> json) {
    return _NotifPrefs(
      rideUpdates: json['rideUpdates'] ?? true,
      chatMessages: json['chatMessages'] ?? true,
      driverApproaching: json['driverApproaching'] ?? true,
      geofenceAlerts: json['geofenceAlerts'] ?? true,
      poolUpdates: json['poolUpdates'] ?? true,
      emailNotifications: json['emailNotifications'] ?? false,
      smsNotifications: json['smsNotifications'] ?? false,
      quietHoursStart: json['quietHoursStart'],
      quietHoursEnd: json['quietHoursEnd'],
    );
  }
}

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<_Notification> _notifications = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';
  int _unreadCount = 0;

  final _filterOptions = const {
    'all': 'All',
    'ride': 'Rides',
    'chat': 'Chat',
    'geofence': 'Geofence',
    'pool': 'Pools',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final typeParam =
          _selectedFilter != 'all' ? '&type=$_selectedFilter' : '';
      final resp =
          await apiClient.get('/notifications?limit=50$typeParam');
      final countResp = await apiClient.get('/notifications/unread-count');

      if (mounted) {
        if (resp.statusCode == 200 && countResp.statusCode == 200) {
          final List<dynamic> data = jsonDecode(resp.body);
          final countData = jsonDecode(countResp.body);
          setState(() {
            _notifications =
                data.map((e) => _Notification.fromJson(e)).toList();
            _unreadCount = countData['count'] ?? 0;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _error = 'Failed to load notifications (${resp.statusCode})';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.put('/notifications/$id/read', {});
      _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.put('/notifications/read-all', {});
      _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.delete('/notifications/$id');
      _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content:
            const Text('Are you sure you want to delete all notifications?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.delete('/notifications');
      _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Notifications'),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Settings'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationsTab(),
              _NotificationSettingsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.dispatcherGradient),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.notifications, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Notification Center',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            if (_unreadCount > 0)
              IconButton(
                icon: const Icon(Icons.done_all, color: Colors.white, size: 22),
                onPressed: _markAllAsRead,
                tooltip: 'Mark all as read',
              ),
            PopupMenuButton<String>(
              icon:
                  const Icon(Icons.more_vert, color: Colors.white, size: 22),
              onSelected: (value) {
                if (value == 'delete_all') _deleteAll();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, size: 18, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Clear All'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return Column(
      children: [
        // Filter chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: _filterOptions.entries.map((entry) {
              final selected = _selectedFilter == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: selected,
                  label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                  onSelected: (val) {
                    setState(() => _selectedFilter = entry.key);
                    _loadNotifications();
                  },
                  selectedColor: Theme.of(context).colorScheme.primary.withAlpha(30),
                  checkmarkColor: Theme.of(context).colorScheme.primary,
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(_error!),
                          ElevatedButton(
                              onPressed: _loadNotifications,
                              child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off,
                                  size: 56, color: Theme.of(context).colorScheme.outlineVariant),
                              const SizedBox(height: 12),
                              Text(
                                'No notifications',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadNotifications,
                          child: _buildGroupedList(),
                        ),
        ),
      ],
    );
  }

  Widget _buildGroupedList() {
    // Group by date
    final grouped = <String, List<_Notification>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final n in _notifications) {
      final nDate = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      String label;
      if (nDate == today) {
        label = 'Today';
      } else if (nDate == yesterday) {
        label = 'Yesterday';
      } else {
        label = DateFormat('MMM d, yyyy').format(n.createdAt);
      }
      grouped.putIfAbsent(label, () => []).add(n);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: grouped.length,
      itemBuilder: (context, groupIndex) {
        final entry = grouped.entries.elementAt(groupIndex);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            ...entry.value.map(_buildNotificationCard),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(_Notification n) {
    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(n.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        color: n.isRead ? null : AppColors.rideAssignedBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: n.isRead
              ? BorderSide.none
              : BorderSide(color: Theme.of(context).colorScheme.primary.withAlpha(30)),
        ),
        child: ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: _typeColor(n.notificationType).withAlpha(20),
            child: Icon(_typeIcon(n.notificationType),
                size: 18, color: _typeColor(n.notificationType)),
          ),
          title: Text(
            n.title,
            style: TextStyle(
              fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
              fontSize: 13,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.body,
                  style: const TextStyle(fontSize: 12), maxLines: 2),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _typeColor(n.notificationType).withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _typeLabel(n.notificationType),
                      style: TextStyle(
                          fontSize: 9,
                          color: _typeColor(n.notificationType),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _timeAgo(n.createdAt),
                    style:
                        TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                ],
              ),
            ],
          ),
          onTap: n.isRead ? null : () => _markAsRead(n.id),
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'ride':
      case 'ride_assigned':
      case 'ride_status':
        return Icons.directions_car;
      case 'chat':
        return Icons.chat;
      case 'geofence':
        return Icons.share_location;
      case 'driver_approaching':
        return Icons.near_me;
      case 'pool':
        return Icons.groups;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'ride':
      case 'ride_assigned':
      case 'ride_status':
        return Theme.of(context).colorScheme.primary;
      case 'chat':
        return AppColors.accent;
      case 'geofence':
        return AppColors.warning;
      case 'driver_approaching':
        return AppColors.warning;
      case 'pool':
        return AppColors.info;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'ride':
      case 'ride_assigned':
      case 'ride_status':
        return 'Ride';
      case 'chat':
        return 'Chat';
      case 'geofence':
        return 'Geofence';
      case 'driver_approaching':
        return 'Approaching';
      case 'pool':
        return 'Pool';
      default:
        return 'System';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _NotificationSettingsTab extends StatefulWidget {
  @override
  State<_NotificationSettingsTab> createState() =>
      _NotificationSettingsTabState();
}

class _NotificationSettingsTabState extends State<_NotificationSettingsTab> {
  _NotifPrefs? _prefs;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    setState(() => _isLoading = true);

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final resp = await apiClient.get('/notification-preferences');
      if (mounted) {
        if (resp.statusCode == 200) {
          setState(() {
            _prefs = _NotifPrefs.fromJson(jsonDecode(resp.body));
            _isLoading = false;
          });
        } else {
          setState(() {
            _prefs = _NotifPrefs();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _prefs = _NotifPrefs();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePrefs() async {
    if (_prefs == null) return;
    setState(() => _isSaving = true);

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.put('/notification-preferences', {
        'rideUpdates': _prefs!.rideUpdates,
        'chatMessages': _prefs!.chatMessages,
        'driverApproaching': _prefs!.driverApproaching,
        'geofenceAlerts': _prefs!.geofenceAlerts,
        'poolUpdates': _prefs!.poolUpdates,
        'emailNotifications': _prefs!.emailNotifications,
        'smsNotifications': _prefs!.smsNotifications,
        if (_prefs!.quietHoursStart != null)
          'quietHoursStart': _prefs!.quietHoursStart,
        if (_prefs!.quietHoursEnd != null)
          'quietHoursEnd': _prefs!.quietHoursEnd,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final prefs = _prefs!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Push Notifications',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        _buildSwitch('Ride Updates', 'Status changes, assignments',
            prefs.rideUpdates, (v) => setState(() => prefs.rideUpdates = v)),
        _buildSwitch(
            'Chat Messages',
            'New messages from driver/client',
            prefs.chatMessages,
            (v) => setState(() => prefs.chatMessages = v)),
        _buildSwitch(
            'Driver Approaching',
            'When driver is near pickup',
            prefs.driverApproaching,
            (v) => setState(() => prefs.driverApproaching = v)),
        _buildSwitch(
            'Geofence Alerts',
            'Entry/exit zone alerts',
            prefs.geofenceAlerts,
            (v) => setState(() => prefs.geofenceAlerts = v)),
        _buildSwitch(
            'Pool Updates',
            'Ride pooling notifications',
            prefs.poolUpdates,
            (v) => setState(() => prefs.poolUpdates = v)),
        const Divider(height: 32),
        Text('Additional Channels',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        _buildSwitch(
            'Email Notifications',
            'Receive notifications via email',
            prefs.emailNotifications,
            (v) => setState(() => prefs.emailNotifications = v)),
        _buildSwitch(
            'SMS Notifications',
            'Receive notifications via SMS',
            prefs.smsNotifications,
            (v) => setState(() => prefs.smsNotifications = v)),
        const Divider(height: 32),
        Text('Quiet Hours',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ListTile(
                title: const Text('From', style: TextStyle(fontSize: 13)),
                subtitle: Text(prefs.quietHoursStart ?? 'Not set',
                    style: const TextStyle(fontSize: 12)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 22, minute: 0),
                  );
                  if (time != null) {
                    setState(() => prefs.quietHoursStart =
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
                  }
                },
              ),
            ),
            Expanded(
              child: ListTile(
                title: const Text('To', style: TextStyle(fontSize: 13)),
                subtitle: Text(prefs.quietHoursEnd ?? 'Not set',
                    style: const TextStyle(fontSize: 12)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 7, minute: 0),
                  );
                  if (time != null) {
                    setState(() => prefs.quietHoursEnd =
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSaving ? null : _savePrefs,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Preferences'),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitch(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle:
          Text(subtitle, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
