import 'package:flutter/material.dart';
import 'package:splitpal/core/app_services.dart';
import 'package:splitpal/api/ai_chat_api.dart';
import 'package:splitpal/models/ai_chat_message.dart';
import 'package:splitpal/models/ai_chat_session.dart';

class AiChatPage extends StatefulWidget {
  final String? initialSessionId;

  const AiChatPage({super.key, this.initialSessionId});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiChatApi _api = AiChatApi(AppServices.dio.dio);
  
  List<AiChatMessage> _messages = [];
  List<AiChatSession> _sessions = [];
  String? _currentSessionId;
  bool _isLoading = false;
  bool _isDrawerLoading = false;

  final List<String> _promptChips = [
    "How much have I spent this month?",
    "Can I afford a new phone?",
    "Summarize my debts",
    "My savings progress"
  ];

  @override
  void initState() {
    super.initState();
    _currentSessionId = widget.initialSessionId;
    if (_currentSessionId != null) {
      _loadHistory(_currentSessionId!);
    } else {
      // Add a greeting message locally
      _messages.add(AiChatMessage(
        id: 'welcome',
        sessionId: '',
        role: 'model',
        content: 'Hello! I am your SplitPal Financial Assistant. How can I help you today?',
        createdAt: DateTime.now(),
      ));
    }
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isDrawerLoading = true);
    try {
      final sessions = await _api.getSessions();
      setState(() => _sessions = sessions);
    } catch (e) {
      debugPrint("Error loading sessions: $e");
    } finally {
      if (mounted) setState(() => _isDrawerLoading = false);
    }
  }

  Future<void> _loadHistory(String sessionId) async {
    setState(() {
      _isLoading = true;
      _currentSessionId = sessionId;
    });
    try {
      final history = await _api.getSessionHistory(sessionId);
      // Filter out function calls, only show user and model text
      setState(() {
        _messages = history.where((m) => m.role != 'function').toList();
      });
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load history')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: _currentSessionId ?? '',
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final res = await _api.sendMessage(text, sessionId: _currentSessionId);
      final replyText = res['reply'] as String? ?? 'No response';
      final newSessionId = res['sessionId'] as String?;

      if (newSessionId != null && _currentSessionId == null) {
        _currentSessionId = newSessionId;
        _loadSessions(); // refresh drawer
      }

      final modelMsg = AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sessionId: _currentSessionId ?? '',
        role: 'model',
        content: replyText,
        createdAt: DateTime.now(),
      );

      setState(() {
        _messages.add(modelMsg);
      });
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send message')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('SplitPal AI Advisor'),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            )
          )
        ],
      ),
      endDrawer: _buildHistoryDrawer(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.role == 'user';
                return _buildMessageBubble(msg, isUser, theme);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          if (_messages.length <= 1) _buildPromptChips(theme),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg, bool isUser, ThemeData theme) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.primary : theme.colorScheme.secondary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
        ),
        child: Text(
          msg.content,
          style: TextStyle(
            color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPromptChips(ThemeData theme) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _promptChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final text = _promptChips[index];
          return ActionChip(
            label: Text(text),
            onPressed: () => _sendMessage(text),
            backgroundColor: theme.colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: theme.colorScheme.onPrimaryContainer, 
              fontWeight: FontWeight.bold
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16).copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Ask about your finances...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Icons.send),
            onPressed: () => _sendMessage(_textController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            child: Text('Chat History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('New Chat'),
            onTap: () {
              setState(() {
                _currentSessionId = null;
                _messages = [
                  AiChatMessage(
                    id: 'welcome',
                    sessionId: '',
                    role: 'model',
                    content: 'Hello! I am your SplitPal Financial Assistant. How can I help you today?',
                    createdAt: DateTime.now(),
                  )
                ];
              });
              Navigator.pop(context);
            },
          ),
          const Divider(),
          if (_isDrawerLoading) const CircularProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final s = _sessions[index];
                return ListTile(
                  title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  selected: s.id == _currentSessionId,
                  onTap: () {
                    _loadHistory(s.id);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
