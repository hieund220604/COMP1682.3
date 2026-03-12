import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/utils/token_manager.dart';

class ChatView extends StatefulWidget {
  final String groupId;
  final String? currentUserId;

  const ChatView({
    super.key,
    required this.groupId,
    this.currentUserId,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChatProvider>();
      provider.init(widget.groupId, currentUserId: widget.currentUserId);
    });
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final provider = context.read<ChatProvider>();
    if (_scrollController.position.pixels <= 120 &&
        provider.hasMore &&
        !provider.isLoading) {
      provider.loadMore();
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final distance =
        _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
    return distance < 200;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final msgCount = provider.messages.length;
        if (msgCount > _previousMessageCount && _isNearBottom()) {
          _scrollToBottom();
        }
        _previousMessageCount = msgCount;

        if (provider.isLoading && provider.messages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.grey[50],
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: provider.messages.length +
                      ((provider.isLoading && provider.hasMore && provider.messages.isNotEmpty) ? 1 : 0),
                  itemBuilder: (context, index) {
                    final showLoader = provider.isLoading &&
                        provider.hasMore &&
                        provider.messages.isNotEmpty;
                    if (showLoader && index == 0) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final offset = showLoader ? 1 : 0;
                    final message = provider.messages[index - offset];
                    final currentUserId = provider.currentUserId ??
                        context.read<AuthProvider>().user?.id ??
                        di.sl<TokenManager>().getUserId();
                    final isMe = currentUserId != null &&
                        (message.senderId == currentUserId ||
                            message.sender?.id == currentUserId);
                    return _MessageBubble(message: message, isMe: isMe);
                  },
                ),
              ),
            ),
            if (provider.error != null)
              Container(
                width: double.infinity,
                color: Colors.red.withOpacity(0.08),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  provider.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            _buildInputBar(context, provider),
          ],
        );
      },
    );
  }

  Widget _buildInputBar(BuildContext context, ChatProvider provider) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(provider),
                decoration: InputDecoration(
                  hintText: 'Aa',
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: provider.isSending ? null : () => _handleSend(provider),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
              ),
              icon: provider.isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSend(ChatProvider provider) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    provider.sendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? AppColors.primary : Colors.white;
    final textColor = isMe ? Colors.white : AppColors.midnightBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _avatar(),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft:
                      Radius.circular(isMe ? 14 : 4), // sharper for incoming
                  bottomRight:
                      Radius.circular(isMe ? 4 : 14), // sharper for mine
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        message.sender?.displayName ?? 'Member',
                        style: TextStyle(
                          color: textColor.withOpacity(0.85),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (message.content != null)
                    Text(
                      message.content!,
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe) _avatar(isMine: true),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dateTime) {
    final hours = dateTime.hour.toString().padLeft(2, '0');
    final minutes = dateTime.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  Widget _avatar({bool isMine = false}) {
    final initials = (message.sender?.displayName ?? 'Me')
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase())
        .take(2)
        .join();
    final bg = isMine ? AppColors.primary.withOpacity(0.15) : Colors.grey[300];
    return CircleAvatar(
      radius: 16,
      backgroundColor: bg,
      backgroundImage: message.sender?.avatarUrl != null
          ? NetworkImage(message.sender!.avatarUrl!)
          : null,
      child: message.sender?.avatarUrl == null
          ? Text(
              initials,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isMine ? AppColors.primary : AppColors.midnightBlue,
              ),
            )
          : null,
    );
  }
}
