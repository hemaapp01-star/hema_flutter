import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hema/theme.dart';
import 'package:hema/services/adk_agent_service.dart';
import 'package:hema/models/message_model.dart';
import 'package:hema/models/blood_request_model.dart';
import 'package:hema/models/healthcare_provider_model.dart';

/// Chat page for donor to interact with Hema AI about blood donation requests
class HemaChatPage extends StatefulWidget {
  final BloodRequestModel request;

  const HemaChatPage({
    super.key,
    required this.request,
  });

  @override
  State<HemaChatPage> createState() => _HemaChatPageState();
}

class _HemaChatPageState extends State<HemaChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _hasAgreed = false;
  String? _hospitalAddress;
  String? _userId;
  HealthcareProviderModel? _providerInfo;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  /// Initialize the chat by loading existing messages from Firestore
  Future<void> _initializeChat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No authenticated user found');
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _userId = user.uid);

      // Fetch provider information
      try {
        final providerDoc = await FirebaseFirestore.instance
            .collection('healthcare_providers')
            .doc(widget.request.providerId)
            .get();
        
        if (providerDoc.exists && providerDoc.data() != null) {
          _providerInfo = HealthcareProviderModel.fromJson(providerDoc.data()!);
          debugPrint('✅ Loaded provider info: ${_providerInfo?.organizationName}');
        }
      } catch (e) {
        debugPrint('⚠️ Error loading provider info: $e');
      }

      // Prepare initial context with blood request and provider location
      Map<String, dynamic>? initialContext;
      if (_providerInfo != null) {
        // Convert request to JSON and format timestamps as strings
        final requestJson = widget.request.toJson();
        requestJson['createdAt'] = widget.request.createdAt.toString();
        requestJson['updatedAt'] = widget.request.updatedAt.toString();
        if (widget.request.requiredBy != null) {
          requestJson['requiredBy'] = widget.request.requiredBy!.toString();
        }
        requestJson['active'] = widget.request.status == RequestStatus.open;

        // Convert provider to JSON and format timestamps as strings
        final providerJson = _providerInfo!.toJson();
        providerJson['createdAt'] = _providerInfo!.createdAt.toString();
        providerJson['updatedAt'] = _providerInfo!.updatedAt.toString();
        
        initialContext = {
          'bloodRequest': requestJson,
          'providerLocation': providerJson,
        };
        
        debugPrint('📝 Prepared context for chat with request ${widget.request.id} and provider ${_providerInfo!.organizationName}');
      }

      // Initialize session
      await AdkAgentService.createSession(
        userId: user.uid,
        sessionId: user.uid,
      );

      // Load existing messages from Firestore
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('donors')
          .doc(user.uid)
          .collection('messages')
          .orderBy('date', descending: false)
          .get();

      final messages = messagesSnapshot.docs
          .map((doc) => MessageModel.fromJson(doc.data(), doc.id))
          .toList();

      // If no messages exist, send initial greeting from Hema
      if (messages.isEmpty) {
        final providerName = _providerInfo?.organizationName ?? 'a healthcare facility';
        final initialMessage = 'Hi! There is a need for ${widget.request.quantity} ${widget.request.quantity == 1 ? "unit" : "units"} of ${widget.request.bloodGroup} blood at $providerName. Are you available to donate?';
        
        // Save initial message to Firestore
        await _saveMessage(
          content: initialMessage,
          role: MessageRole.hema,
        );

        messages.add(MessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: initialMessage,
          role: MessageRole.hema,
          date: DateTime.now(),
        ));
      }

      setState(() {
        _messages.addAll(messages);
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Save a message to Firestore
  Future<void> _saveMessage({
    required String content,
    required MessageRole role,
  }) async {
    try {
      if (_userId == null) return;

      await FirebaseFirestore.instance
          .collection('donors')
          .doc(_userId)
          .collection('messages')
          .add({
        'content': content,
        'role': role.toJson(),
        'date': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error saving message to Firestore: $e');
    }
  }

  /// Send a message to either Hema ADK agent or directly to the provider
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _userId == null) return;

    final userMessage = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      role: MessageRole.user,
      date: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _messageController.clear();
    });

    _scrollToBottom();

    // Save user message to Firestore
    await _saveMessage(
      content: text,
      role: MessageRole.user,
    );

    try {
      // Check if the last message (before the user's message) is from a provider
      final lastNonUserMessage = _messages.length >= 2
          ? _messages[_messages.length - 2]
          : null;
      
      final isChattingWithProvider = lastNonUserMessage?.isProvider ?? false;
      
      if (isChattingWithProvider && lastNonUserMessage?.providerId != null) {
        // The conversation has been handed over to the provider
        // Send message directly to Firebase instead of ADK agent
        debugPrint('🏥 Conversation handed over to provider. Sending message to Firebase.');
        
        final providerId = lastNonUserMessage!.providerId!;
        
        // Save donor message to Firebase
        await _saveDonorMessageToProvider(
          providerId: providerId,
          requestId: widget.request.id,
          content: text,
        );
        
        setState(() => _isLoading = false);
        
        debugPrint('✅ Message sent to provider at: healthcare_providers/$providerId/conversations/${widget.request.id}/donors/$_userId/messages');
      } else {
        // Hema is still handling the conversation - send to ADK agent
        debugPrint('🤖 Hema is handling the conversation. Sending message to ADK agent.');
        
        // Prepare initial context with blood request and provider location
        Map<String, dynamic>? initialContext;
        if (_providerInfo != null) {
          // Convert request to JSON and format timestamps as strings
          final requestJson = widget.request.toJson();
          requestJson['createdAt'] = widget.request.createdAt.toString();
          requestJson['updatedAt'] = widget.request.updatedAt.toString();
          if (widget.request.requiredBy != null) {
            requestJson['requiredBy'] = widget.request.requiredBy!.toString();
          }
          requestJson['active'] = widget.request.status == RequestStatus.open;

          // Convert provider to JSON and format timestamps as strings
          final providerJson = _providerInfo!.toJson();
          providerJson['createdAt'] = _providerInfo!.createdAt.toString();
          providerJson['updatedAt'] = _providerInfo!.updatedAt.toString();
          
          initialContext = {
            'bloodRequest': requestJson,
            'providerLocation': providerJson,
          };
          
          debugPrint('📝 Prepared initial context with request ${widget.request.id} and provider ${_providerInfo!.organizationName}');
        }

        // Call Hema agent API with user's Firebase UID as both userId and session ID
        final response = await AdkAgentService.sendMessage(
          userId: _userId!,
          sessionId: _userId!,
          message: text,
          context: initialContext,
        );

        final aiMessage = MessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response,
          role: MessageRole.hema,
          date: DateTime.now(),
        );

        // Save agent response to Firestore
        await _saveMessage(
          content: response,
          role: MessageRole.hema,
        );

        // Check if user has agreed to donate
        if (text.toLowerCase().contains('yes') || 
            text.toLowerCase().contains('available') ||
            text.toLowerCase().contains('can donate') ||
            text.toLowerCase().contains('i\'ll go') ||
            text.toLowerCase().contains('on my way')) {
          
          if (response.toLowerCase().contains('address') && _providerInfo != null) {
            setState(() {
              _hasAgreed = true;
              _hospitalAddress = _providerInfo!.address;
            });
          }
        }

        setState(() {
          _messages.add(aiMessage);
          _isLoading = false;
        });
      }

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      
      final errorMessage = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Sorry, I\'m having trouble connecting right now. Please try again.',
        role: MessageRole.hema,
        date: DateTime.now(),
      );

      setState(() {
        _messages.add(errorMessage);
        _isLoading = false;
      });
      
      _scrollToBottom();
    }
  }

  /// Save donor's message to provider's Firebase collection
  /// Path: healthcare_providers/{providerId}/conversations/{requestId}/donors/{donorId}/messages/{messageId}
  Future<void> _saveDonorMessageToProvider({
    required String providerId,
    required String requestId,
    required String content,
  }) async {
    try {
      final messageData = {
        'content': content,
        'role': 'donor',
        'date': Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('healthcare_providers')
          .doc(providerId)
          .collection('conversations')
          .doc(requestId)
          .collection('donors')
          .doc(_userId)
          .collection('messages')
          .add(messageData);

      debugPrint('✅ Donor message saved to healthcare_providers/$providerId/conversations/$requestId/donors/$_userId/messages');
    } catch (e) {
      debugPrint('❌ Error saving donor message to provider: $e');
      rethrow;
    }
  }

  /// Scroll to the bottom of the chat
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hema',
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Blood Donation Assistant',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF1A1C1E), const Color(0xFF2D1B1B)]
                      : [const Color(0xFFFFF5F5), const Color(0xFFFFEBEE)],
                ),
              ),
              child: _isLoading && _messages.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: AppSpacing.paddingMd,
                      itemCount: _messages.length + (_isLoading && _messages.isNotEmpty ? 1 : 0) + (_hasAgreed && _hospitalAddress != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show hospital address card after agreement
                        if (_hasAgreed && _hospitalAddress != null && index == _messages.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: HospitalAddressCard(
                              hospitalName: _providerInfo?.organizationName ?? 'Healthcare Facility',
                              address: _hospitalAddress!,
                              distance: _providerInfo != null ? '${_providerInfo!.city}' : 'Near you',
                            ),
                          );
                        }

                        // Show loading indicator
                        if (index == _messages.length + (_hasAgreed && _hospitalAddress != null ? 1 : 0)) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: TypingIndicator(),
                          );
                        }

                        final adjustedIndex = index;
                        final message = _messages[adjustedIndex];
                        return ChatBubble(message: message);
                      },
                    ),
            ),
          ),

          // Message input
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: () => _sendMessage(_messageController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chat bubble widget
class ChatBubble extends StatefulWidget {
  final MessageModel message;

  const ChatBubble({super.key, required this.message});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  String? _providerName;
  bool _loadingProvider = false;

  @override
  void initState() {
    super.initState();
    if (widget.message.isProvider) {
      _loadProviderName();
    }
  }

  Future<void> _loadProviderName() async {
    if (widget.message.providerId == null || _loadingProvider) return;
    
    setState(() => _loadingProvider = true);
    
    try {
      final providerDoc = await FirebaseFirestore.instance
          .collection('healthcare_providers')
          .doc(widget.message.providerId)
          .get();
      
      if (providerDoc.exists && providerDoc.data() != null) {
        final data = providerDoc.data()!;
        setState(() {
          _providerName = data['organizationName'] as String?;
          _loadingProvider = false;
        });
      } else {
        setState(() => _loadingProvider = false);
      }
    } catch (e) {
      debugPrint('Error loading provider name: $e');
      setState(() => _loadingProvider = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = widget.message.role == MessageRole.user;
    final isProvider = widget.message.isProvider;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: isProvider
                    ? const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                      )
                    : LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                        ],
                      ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isProvider ? Icons.local_hospital : Icons.favorite,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : isProvider
                        ? const Color(0xFF4CAF50)
                        : (isDark ? Colors.grey[800] : Colors.white),
                borderRadius: BorderRadius.circular(20).copyWith(
                  topLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
                  topRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isProvider && _providerName != null) ...[
                    Text(
                      _providerName!,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (isProvider && _loadingProvider) ...[
                    const SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    widget.message.content,
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: isUser || isProvider
                          ? Colors.white
                          : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 40),
          if (!isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// Typing indicator for when Hema is responding
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(20).copyWith(
              topLeft: const Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BouncingDot(delay: 0),
              const SizedBox(width: 4),
              _BouncingDot(delay: 200),
              const SizedBox(width: 4),
              _BouncingDot(delay: 400),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bouncing dot animation for typing indicator
class _BouncingDot extends StatefulWidget {
  final int delay;

  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isDark ? Colors.white54 : Colors.black54,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Hospital address card shown when donor agrees to donate
class HospitalAddressCard extends StatelessWidget {
  final String hospitalName;
  final String address;
  final String distance;

  const HospitalAddressCard({
    super.key,
    required this.hospitalName,
    required this.address,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_hospital,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hospitalName,
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.directions_car,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '$distance away',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Open maps or navigation
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.navigation, size: 20),
              label: Text(
                'Get Directions',
                style: context.textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
