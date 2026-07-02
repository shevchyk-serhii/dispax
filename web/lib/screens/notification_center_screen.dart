import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../modules/core/services/error_messages.dart';
import '../modules/core/services/api_client.dart';

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

  _Notification copyWith({bool? isRead}) {
    return _Notification(
      id: id,
      title: title,
      body: body,
      notificationType: notificationType,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      data: data,
    );
  }

  factory _Notification.fromJson(Map<String, dynamic> json) {
    // Tolerate both the flat-string id ("uuid") and the legacy {"value": "uuid"}
    // object form so deserialization never crashes.
    final rawId = json['id'];
    final id = rawId is Map
        ? (rawId['value']?.toString() ?? '')
        : (rawId?.toString() ?? '');
    final rawCreatedAt = json['createdAt'];
    final createdAt = rawCreatedAt is String
        ? DateTime.tryParse(rawCreatedAt) ?? DateTime.now()
        : DateTime.now();
    return _Notification(
      id: id,
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      notificationType: json['notificationType']?.toString() ?? '',
      createdAt: createdAt,
      isRead: json['isRead'] == true,
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
  Object? _error;
  String _selectedFilter = 'all';
  int _unreadCount = 0;

  Map<String, String> _filterOptions(AppLocalizations l10n) => {
    'all': l10n.notifFilterAll,
    'ride': l10n.notifFilterRides,
    'chat': l10n.notifFilterChat,
    'geofence': l10n.notifFilterGeofence,
    'pool': l10n.notifFilterPools,
    'airport_checkpoint': l10n.notifFilterCheckpoints,
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
      final typeParam = _selectedFilter != 'all'
          ? '&type=$_selectedFilter'
          : '';
      final responses = await Future.wait([
        apiClient.get('/notifications?limit=50$typeParam'),
        apiClient.get('/notifications/unread-count'),
      ]);
      final resp = responses[0];
      final countResp = responses[1];

      if (mounted) {
        if (resp.statusCode == 200 && countResp.statusCode == 200) {
          final List<dynamic> data = jsonDecode(resp.body);
          final countData = jsonDecode(countResp.body);
          setState(() {
            _notifications = data
                .map((e) => _Notification.fromJson(e))
                .toList();
            _unreadCount = countData['count'] ?? 0;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _error = ApiException(
              'Failed to load notifications',
              statusCode: resp.statusCode,
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.put('/notifications/$id/read', {});
      if (!mounted) return;
      setState(() {
        var decremented = false;
        _notifications = _notifications.map((n) {
          if (n.id == id && !n.isRead) {
            decremented = true;
            return n.copyWith(isRead: true);
          }
          return n;
        }).toList();
        if (decremented && _unreadCount > 0) _unreadCount--;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.operationFailed(friendlyError(e, AppLocalizations.of(context)!)),
          ),
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.put('/notifications/read-all', {});
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => n.isRead ? n : n.copyWith(isRead: true))
            .toList();
        _unreadCount = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.operationFailed(friendlyError(e, AppLocalizations.of(context)!)),
          ),
        ),
      );
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.delete('/notifications/$id');
      if (!mounted) return;
      setState(() {
        final removed = _notifications.where((n) => n.id == id).toList();
        final wasUnread = removed.any((n) => !n.isRead);
        _notifications = _notifications.where((n) => n.id != id).toList();
        if (wasUnread && _unreadCount > 0) _unreadCount--;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.operationFailed(friendlyError(e, AppLocalizations.of(context)!)),
          ),
        ),
      );
    }
  }

  Future<void> _deleteAll() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearAllConfirmTitle),
        content: Text(l10n.clearAllConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.deleteAllNotificationsButton),
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
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.operationFailed(friendlyError(e, AppLocalizations.of(context)!)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildGraphiteHeader(l10n),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.notifTabNotifications),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: l10n.notifTabSettings),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationsTab(l10n),
              _NotificationSettingsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Graphite header with "Mark all read" accent link ─────────────────────

  Widget _buildGraphiteHeader(AppLocalizations l10n) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.notifications,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (_unreadCount > 0)
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: Text(
                      l10n.markAllReadButton,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 22,
                  ),
                  onSelected: (value) {
                    if (value == 'delete_all') _deleteAll();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete_all',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_sweep,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Text(l10n.clearAllNotificationsMenuLabel),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsTab(AppLocalizations l10n) {
    final filterOpts = _filterOptions(l10n);
    return Column(
      children: [
        // Filter chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: filterOpts.entries.map((entry) {
              final selected = _selectedFilter == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: selected,
                  label: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onSelected: (val) {
                    setState(() => _selectedFilter = entry.key);
                    _loadNotifications();
                  },
                  selectedColor: AppColors.accent.withAlpha(30),
                  checkmarkColor: AppColors.accent,
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator.adaptive())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 12),
                      Text(friendlyError(_error, l10n)),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 56,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noNotificationsYet,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: _buildGroupedList(l10n),
                ),
        ),
      ],
    );
  }

  // ─── Grouped list cache ───────────────────────────────────────────────────

  List<_Notification>? _groupedSource;
  List<MapEntry<String, List<_Notification>>> _groupedEntries = const [];

  List<MapEntry<String, List<_Notification>>> _computeGroupedEntries(
    AppLocalizations l10n,
  ) {
    if (identical(_groupedSource, _notifications)) return _groupedEntries;

    final grouped = <String, List<_Notification>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final n in _notifications) {
      final nDate = DateTime(
        n.createdAt.year,
        n.createdAt.month,
        n.createdAt.day,
      );
      String label;
      if (nDate == today) {
        label = l10n.today;
      } else if (nDate == yesterday) {
        label = l10n.yesterday;
      } else {
        label = DateFormat('MMM d, yyyy').format(n.createdAt);
      }
      grouped.putIfAbsent(label, () => []).add(n);
    }

    _groupedSource = _notifications;
    _groupedEntries = grouped.entries.toList();
    return _groupedEntries;
  }

  Widget _buildGroupedList(AppLocalizations l10n) {
    final entries = _computeGroupedEntries(l10n);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: entries.length,
      itemBuilder: (context, groupIndex) {
        final entry = entries[groupIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...entry.value.map((n) => _buildNotificationCard(n, l10n)),
          ],
        );
      },
    );
  }

  // ─── Notification card — new design ───────────────────────────────────────

  Widget _buildNotificationCard(_Notification n, AppLocalizations l10n) {
    final cardStyle = _cardStyle(n.notificationType);

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
      child: GestureDetector(
        onTap: n.isRead ? null : () => _markAsRead(n.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border(
              left: BorderSide(color: cardStyle.leftBorder, width: 3),
              top: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.borderDark
                    : AppColors.borderPrimary,
              ),
              right: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.borderDark
                    : AppColors.borderPrimary,
              ),
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.borderDark
                    : AppColors.borderPrimary,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon box 34x34
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cardStyle.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _typeIcon(n.notificationType),
                    size: 17,
                    color: cardStyle.iconColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: n.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (!n.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n.body,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timeAgo(l10n, n.createdAt),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Card style by type ───────────────────────────────────────────────────

  _CardStyle _cardStyle(String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case 'ride':
      case 'ride_assigned':
      case 'ride_status':
        // alert — red border-left
        return _CardStyle(
          leftBorder: const Color(0xFFEF4444),
          iconBg: isDark ? AppColors.rideCancelledBgDark : AppColors.errorBg,
          iconColor: const Color(0xFFEF4444),
        );
      case 'chat':
      case 'pool':
        // info — blue
        return _CardStyle(
          leftBorder: const Color(0xFF3B82F6),
          iconBg: isDark ? AppColors.rideAssignedBgDark : AppColors.infoBg,
          iconColor: const Color(0xFF3B82F6),
        );
      case 'geofence':
      case 'driver_approaching':
        // success — green
        return _CardStyle(
          leftBorder: const Color(0xFF22C55E),
          iconBg: isDark ? AppColors.rideCompletedBgDark : AppColors.successBg,
          iconColor: const Color(0xFF22C55E),
        );
      default:
        // neutral
        return _CardStyle(
          leftBorder: isDark ? AppColors.borderDark : AppColors.borderSecondary,
          iconBg: isDark
              ? AppColors.surfaceVariantDark
              : AppColors.primarySurface,
          iconColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondary,
        );
    }
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

  String _timeAgo(AppLocalizations l10n, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l10n.notifJustNow;
    if (diff.inMinutes < 60) return l10n.notifMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.notifHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.notifDaysAgo(diff.inDays);
    return DateFormat('MMM d').format(dt);
  }
}

class _CardStyle {
  final Color leftBorder;
  final Color iconBg;
  final Color iconColor;

  const _CardStyle({
    required this.leftBorder,
    required this.iconBg,
    required this.iconColor,
  });
}

// ─── Notification settings tab (unchanged logic, same adaptive switches) ──

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
    final prefs = _prefs;
    if (prefs == null) return;
    setState(() => _isSaving = true);

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.put('/notification-preferences', {
        'rideUpdates': prefs.rideUpdates,
        'chatMessages': prefs.chatMessages,
        'driverApproaching': prefs.driverApproaching,
        'geofenceAlerts': prefs.geofenceAlerts,
        'poolUpdates': prefs.poolUpdates,
        'emailNotifications': prefs.emailNotifications,
        'smsNotifications': prefs.smsNotifications,
        if (prefs.quietHoursStart != null)
          'quietHoursStart': prefs.quietHoursStart,
        if (prefs.quietHoursEnd != null) 'quietHoursEnd': prefs.quietHoursEnd,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.preferencesSaved),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e, AppLocalizations.of(context)!)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator.adaptive());
    }

    final prefs = _prefs;
    if (prefs == null) {
      return Center(child: CircularProgressIndicator.adaptive());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.notifPrefSectionPush,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        _buildSwitch(
          context,
          l10n.rideUpdates,
          l10n.notifPrefRideUpdatesSubtitle,
          prefs.rideUpdates,
          (v) => setState(() => prefs.rideUpdates = v),
        ),
        _buildSwitch(
          context,
          l10n.chatMessages,
          l10n.notifPrefChatMessagesSubtitle,
          prefs.chatMessages,
          (v) => setState(() => prefs.chatMessages = v),
        ),
        _buildSwitch(
          context,
          l10n.notifPrefDriverApproachingLabel,
          l10n.notifPrefDriverApproachingSubtitle,
          prefs.driverApproaching,
          (v) => setState(() => prefs.driverApproaching = v),
        ),
        _buildSwitch(
          context,
          l10n.notifPrefGeofenceAlertsLabel,
          l10n.notifPrefGeofenceAlertsSubtitle,
          prefs.geofenceAlerts,
          (v) => setState(() => prefs.geofenceAlerts = v),
        ),
        _buildSwitch(
          context,
          l10n.notifPrefPoolUpdatesLabel,
          l10n.notifPrefPoolUpdatesSubtitle,
          prefs.poolUpdates,
          (v) => setState(() => prefs.poolUpdates = v),
        ),
        const Divider(height: 32),
        Text(
          l10n.notifPrefSectionAdditional,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        _buildSwitch(
          context,
          l10n.notifPrefEmailLabel,
          l10n.notifPrefEmailSubtitle,
          prefs.emailNotifications,
          (v) => setState(() => prefs.emailNotifications = v),
        ),
        _buildSwitch(
          context,
          l10n.notifPrefSmsLabel,
          l10n.notifPrefSmsSubtitle,
          prefs.smsNotifications,
          (v) => setState(() => prefs.smsNotifications = v),
        ),
        const Divider(height: 32),
        Text(
          l10n.notifPrefQuietHours,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ListTile(
                title: Text(
                  l10n.notifPrefQuietHoursFrom,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  prefs.quietHoursStart ?? l10n.notifPrefNotSet,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 22, minute: 0),
                  );
                  if (time != null) {
                    setState(
                      () => prefs.quietHoursStart =
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    );
                  }
                },
              ),
            ),
            Expanded(
              child: ListTile(
                title: Text(
                  l10n.notifPrefQuietHoursTo,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  prefs.quietHoursEnd ?? l10n.notifPrefNotSet,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 7, minute: 0),
                  );
                  if (time != null) {
                    setState(
                      () => prefs.quietHoursEnd =
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    );
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
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.savePreferencesButton),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitch(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.accent,
      contentPadding: EdgeInsets.zero,
    );
  }
}
