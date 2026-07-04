import 'dart:async';
import '../modules/core/services/api_client.dart' show ApiException;
import '../modules/core/services/error_messages.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../modules/core/services/websocket_service.dart';
import '../modules/ride_management/models/ride.dart';
import '../l10n/app_localizations.dart';

class ChatScreen extends StatefulWidget {
  final Ride ride;

  const ChatScreen({super.key, required this.ride});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<_ChatMsg> _messages = [];
  bool _isLoading = true;
  // Set when loading failed (network error OR a non-200 such as the backend's
  // 403 participation refusal) — renders an error state with Retry instead of
  // an infinite spinner (ApiClient returns non-2xx responses, it doesn't throw).
  bool _loadFailed = false;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenForNewMessages();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _wsSubscription?.cancel();
    super.dispose();
  }

  void _listenForNewMessages() {
    _wsSubscription = WebSocketService.instance.eventStream.listen((event) {
      if (!mounted) return;
      if (event.type == 'ChatMessageSent' &&
          event.data['rideId'] == widget.ride.id) {
        _loadMessages();
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.get('/rides/${widget.ride.id}/chat');

      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        setState(() {
          _messages = jsonList.map((j) => _ChatMsg.fromJson(j)).toList();
          _isLoading = false;
          _loadFailed = false;
        });
        _scrollToBottom();
      } else {
        // e.g. 403 from the backend participation guard — without this branch
        // the screen spun forever, since ApiClient returns non-2xx instead of
        // throwing.
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.post('/rides/${widget.ride.id}/chat', {
        'message': text,
      });
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Clear only once the backend accepted the message — clearing before
        // the POST lost the typed text on a rejection.
        _messageCtrl.clear();
        await _loadMessages();
      } else {
        // Rejected (400 validation / 403 not a party): ApiClient does not
        // throw on non-2xx, so without this branch the message vanished with
        // no feedback. Keep the typed text and tell the user.
        _showSendFailure(ApiException.fromResponse(response, 'send message'));
      }
    } catch (e) {
      _showSendFailure(e);
    }
  }

  void _showSendFailure(Object error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.failedToSendMessage(friendlyError(error, l10n))),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUserId = context.read<AuthBloc>().state.user?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isChatAvailable =
        widget.ride.status == RideStatus.assigned ||
        widget.ride.status == RideStatus.inProgress;

    final ridePickupLabel = DateFormat(
      'dd.MM HH:mm',
    ).format(widget.ride.pickupDateTime);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.surfaceVariant,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            // Driver avatar placeholder
            CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.accent.withValues(alpha: 0.25),
              child: const Icon(
                Icons.person_outline,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.ride.driverName ?? widget.ride.clientName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.onlineOnRideLabel(ridePickupLabel),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Messages thread ────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator.adaptive())
                : _loadFailed
                ? _buildLoadError(l10n)
                : _messages.isEmpty
                ? _buildEmptyState(context, l10n)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + 1, // +1 for date separator
                    itemBuilder: (context, index) {
                      // First item = date separator
                      if (index == 0) return _buildDateSeparator(l10n);
                      final msg = _messages[index - 1];
                      final isMe = msg.senderId == currentUserId;
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),

          // ── Input bar ──────────────────────────────────────────────────────
          if (isChatAvailable)
            _buildInputBar(isDark, l10n)
          else
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingMedium),
              color: isDark
                  ? AppColors.surfaceVariantDark
                  : AppColors.surfaceVariant,
              child: Text(
                l10n.chatUnavailable,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Date separator "Today" ────────────────────────────────────────────────

  Widget _buildDateSeparator(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final lineColor = cs.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: lineColor, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.today,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: lineColor, height: 1)),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildLoadError(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.errorLoadingData,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _loadFailed = false;
              });
              _loadMessages();
            },
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noMessages,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.startConversationSubtitle,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Message bubble ────────────────────────────────────────────────────────
  // dispatcher (isMe) = right, graphite background, white text
  // driver (!isMe)    = left, white/surface background, dark text

  Widget _buildMessageBubble(_ChatMsg msg, bool isMe) {
    // Dispatcher bubble: graphite (#18181B) with white text, radius 14/14/4/14
    // Driver bubble: white/surface with border, radius 14/14/14/4
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 14),
          ),
          border: isMe
              ? null
              : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowXs,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              msg.message,
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(msg.sentAt),
              style: TextStyle(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.6)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Input pill ────────────────────────────────────────────────────────────

  Widget _buildInputBar(bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceVariantDark
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.typeMessage,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  maxLines: 4,
                  minLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Accent circular send button
            Material(
              color: AppColors.accent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sendMessage,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class _ChatMsg {
  final String id;
  final String rideId;
  final String senderId;
  final String message;
  final DateTime sentAt;

  _ChatMsg({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.message,
    required this.sentAt,
  });

  factory _ChatMsg.fromJson(Map<String, dynamic> json) {
    return _ChatMsg(
      id: json['id']?.toString() ?? '',
      rideId: json['rideId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      message: json['message'] ?? '',
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
