import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';
import 'package:hema/models/user_model.dart';
import 'package:hema/models/blood_request_model.dart';
import 'package:hema/services/chat_service.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Chat page for provider-donor conversation
class ProviderDonorChatPage extends StatefulWidget {
  final UserModel donor;
  final BloodRequestModel request;
  final String providerId;

  const ProviderDonorChatPage({
    super.key,
    required this.donor,
    required this.request,
    required this.providerId,
  });

  @override
  State<ProviderDonorChatPage> createState() => _ProviderDonorChatPageState();
}

class _ProviderDonorChatPageState extends State<ProviderDonorChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _sessionReady = false; // Track if session/path is confirmed to exist
  bool _cacheLoaded = false;

  @override
  void initState() {
    super.initState();
    // Load from cache immediately (non-blocking UI)
    _loadMessagesFromCache();
    // Ensure session exists and load fresh messages (parallel operations)
    _ensureSessionAndLoadMessages();
  }

  /// Load messages from Firestore cache immediately (instant load)
  Future<void> _loadMessagesFromCache() async {
    try {
      // Try Firestore cache first (fastest)
      final messages = await _chatService.getMessages(
        donorId: widget.donor.id,
        requestId: widget.request.id,
        providerId: widget.providerId,
        source: Source.cache,
      );

      if (mounted && messages.isNotEmpty) {
        setState(() {
          _messages = messages;
          _cacheLoaded = true;
        });
        _scrollToBottom();
      } else {
        // Fallback to SharedPreferences cache
        final prefs = await SharedPreferences.getInstance();
        final cacheKey = 'chat_${widget.providerId}_${widget.request.id}_${widget.donor.id}';
        final cachedData = prefs.getString(cacheKey);
        
        if (cachedData != null) {
          final List<dynamic> decoded = jsonDecode(cachedData);
          final cachedMessages = decoded.map((item) {
            return ChatMessage(
              id: item['id'] as String,
              content: item['content'] as String,
              role: item['role'] as String,
              date: DateTime.parse(item['timestamp'] as String),
              providerId: item['providerId'] as String?,
              requestId: item['requestId'] as String?,
            );
          }).toList();

          if (mounted) {
            setState(() {
              _messages = cachedMessages;
              _cacheLoaded = true;
            });
            _scrollToBottom();
          }
        } else {
          // No cache available, show loading
          if (mounted) {
            setState(() {
              _cacheLoaded = true;
              _isLoading = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading messages from cache: $e');
      if (mounted) {
        setState(() {
          _cacheLoaded = true;
          _isLoading = true;
        });
      }
    }
  }

  /// Ensure session exists and load fresh messages
  Future<void> _ensureSessionAndLoadMessages() async {
    try {
      // Ensure the session path exists in Firestore
      await _chatService.ensureSessionExists(
        donorId: widget.donor.id,
        requestId: widget.request.id,
        providerId: widget.providerId,
      );

      if (mounted) {
        setState(() => _sessionReady = true);
      }

      // Load fresh messages from server (with cache fallback)
      final messages = await _chatService.getMessages(
        donorId: widget.donor.id,
        requestId: widget.request.id,
        providerId: widget.providerId,
      );

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });

        // Save to SharedPreferences cache for next time
        await _saveMessagesToCache(messages);
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _sessionReady = true; // Allow sending even if load failed
        });
      }
    }
  }

  /// Save messages to local cache
  Future<void> _saveMessagesToCache(List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'chat_${widget.providerId}_${widget.request.id}_${widget.donor.id}';
      final encoded = jsonEncode(
        messages.map((msg) => {
          'id': msg.id,
          'content': msg.content,
          'role': msg.role,
          'timestamp': msg.date.toIso8601String(),
          'providerId': msg.providerId,
          'requestId': msg.requestId,
        }).toList(),
      );
      await prefs.setString(cacheKey, encoded);
    } catch (e) {
      debugPrint('Error saving messages to cache: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || !_sessionReady) return;

    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        donorId: widget.donor.id,
        requestId: widget.request.id,
        providerId: widget.providerId,
        content: text,
      );

      _messageController.clear();

      // Reload messages
      final messages = await _chatService.getMessages(
        donorId: widget.donor.id,
        requestId: widget.request.id,
        providerId: widget.providerId,
      );

      if (mounted) {
        setState(() => _messages = messages);
        await _saveMessagesToCache(messages);
      }

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.1),
              child: Text(
                widget.donor.firstName[0].toUpperCase(),
                style: context.textStyles.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.donor.fullName,
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.donor.bloodType != null)
                    Text(
                      widget.donor.bloodType!.displayName,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Request context banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.water_drop,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Request: ${widget.request.title}',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: context.textStyles.titleMedium?.copyWith(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start a conversation with ${widget.donor.firstName}',
                              style: context.textStyles.bodySmall?.copyWith(
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return ChatMessageBubble(
                            message: message,
                            isDark: isDark,
                          );
                        },
                      ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: _sessionReady,
                    decoration: InputDecoration(
                      hintText: _sessionReady ? 'Type a message...' : 'Preparing chat...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _sessionReady
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? Colors.grey[700] : Colors.grey[400]),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: (_isSending || !_sessionReady) ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chat message bubble widget
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isProvider = message.role.startsWith('provider-');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isProvider ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isProvider) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.1),
              child: Icon(
                Icons.person,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isProvider
                    ? Theme.of(context).colorScheme.primary
                    : isDark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: isProvider
                          ? Colors.white
                          : isDark
                              ? Colors.white
                              : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.date),
                    style: context.textStyles.bodySmall?.copyWith(
                      color: isProvider
                          ? Colors.white70
                          : isDark
                              ? Colors.white60
                              : Colors.black54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isProvider) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.2),
              child: Icon(
                Icons.local_hospital,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
