import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/settings/pages/settings_page.dart';
import 'package:gyeol/engine/chat/chat_service.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/model_fetcher.dart';

class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel({super.key});

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final _inputFocusNode = FocusNode(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed &&
          !HardwareKeyboard.instance.isControlPressed) {
        _sendMessage();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );
  StreamSubscription<Object>? _streamSub;
  String _streamingContent = '';
  String _errorMessage = '';
  bool _isStreaming = false;
  final _consumedToolIds = <String>{};
  List<ChatMessage> _localMessages = [];

  @override
  void dispose() {
    _streamSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
  }

  Future<void> _regenerateResponse(
    String convId,
    String userMessage,
    List<ChatMessage> history,
  ) async {
    ref.read(chatSendingProvider.notifier).state = true;
    try {
      final chatService = ref.read(chatServiceProvider);
      final result = await chatService.handleMessage(userMessage, history);
      for (final msg in result.newMessages) {
        if (msg.role != 'user') {
          final saved = ChatMessage.create(
            conversationId: convId,
            role: msg.role,
            content: msg.content,
            toolName: msg.toolName,
            toolCallId: msg.toolCallId,
          );
          await ref.read(repositoryProvider).chat.saveMessage(saved);
        }
      }
      ref.invalidate(chatMessagesProvider(convId));
      _scrollToBottom();
    } finally {
      ref.read(chatSendingProvider.notifier).state = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    ref.read(chatSendingProvider.notifier).state = true;
    _errorMessage = '';

    try {
      var convId = ref.read(selectedConversationIdProvider);

      if (convId == null) {
        final conv = await ref
            .read(conversationsProvider.notifier)
            .createConversation(
              text.length > 30 ? text.substring(0, 30) : text,
            );
        convId = conv.id;
        ref.read(selectedConversationIdProvider.notifier).state = convId;
      }

      final repo = ref.read(repositoryProvider);
      final userMsg = ChatMessage.create(
        conversationId: convId,
        role: 'user',
        content: text,
      );
      await repo.chat.saveMessage(userMsg);
      ref.invalidate(chatMessagesProvider(convId));
      final history = await repo.chat.listMessages(convId);
      _localMessages = List.of(history);

      final chatService = ref.read(chatServiceProvider);

      _streamingContent = '';
      _isStreaming = true;
      setState(() {});

      final stream = chatService.handleMessageStream(text, history);
      _streamSub = stream.listen(
        (event) {
          if (event is ChatStreamTextEvent) {
            _streamingContent += event.text;
            setState(() {});
            _scrollToBottom();
          } else if (event is ChatStreamToolEvent) {
            final toolMsg = ChatMessage.create(
              conversationId: convId!,
              role: 'tool',
              content: event.content,
              toolName: event.toolName,
            );
            repo.chat.saveMessage(toolMsg).then((_) {
              _localMessages.add(toolMsg);
              setState(() {});
              _scrollToBottom();
            });
          }
        },
        onDone: () async {
          final content = _streamingContent;
          _streamingContent = '';
          _isStreaming = false;
          setState(() {});

          if (content.isNotEmpty) {
            final saved = ChatMessage.create(
              conversationId: convId!,
              role: 'assistant',
              content: content,
            );
            await repo.chat.saveMessage(saved);
            _localMessages.add(saved);
            setState(() {});
          }
          _streamSub = null;
          ref.invalidate(chatMessagesProvider(convId!));
          ref.read(chatSendingProvider.notifier).state = false;
          _scrollToBottom();
        },
        onError: (Object e) {
          _isStreaming = false;
          _streamingContent = '';
          _errorMessage = e is LlmError ? e.message : e.toString();
          _streamSub = null;
          setState(() {});
          if (convId != null) {
            ref.invalidate(chatMessagesProvider(convId));
          }
          ref.read(chatSendingProvider.notifier).state = false;
        },
        cancelOnError: true,
      );
    } on Object catch (e) {
      _isStreaming = false;
      _streamingContent = '';
      _errorMessage = e is LlmError ? e.message : e.toString();
      setState(() {});
      ref.read(chatSendingProvider.notifier).state = false;
    }
  }

  void _stopStreaming() {
    _streamSub?.cancel();
    _streamSub = null;
    _isStreaming = false;
    _streamingContent = '';
    _errorMessage = '';
    setState(() {});
    ref.read(chatSendingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final convId = ref.watch(selectedConversationIdProvider);
    final conversationsAsync = ref.watch(conversationsProvider);
    final isSending = ref.watch(chatSendingProvider);

    if (convId == null) {
      final convs = conversationsAsync.valueOrNull;
      if (convs != null && convs.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(selectedConversationIdProvider.notifier).state =
              convs.first.id;
        });
      }
    }

    final messagesAsync = convId != null
        ? ref.watch(chatMessagesProvider(convId))
        : null;

    return Column(
      children: [
        _buildToolbar(conversationsAsync),
        const Divider(height: 1),
        Expanded(child: _buildMessages(messagesAsync, isSending)),
        if (convId == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(selectedConversationIdProvider.notifier).state =
                      null;
                },
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  'New conversation',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
          ),
        const Divider(height: 1),
        _buildInput(isSending),
      ],
    );
  }

  Widget _buildToolbar(AsyncValue<List<ChatConversation>> conversationsAsync) {
    final settingsAsync = ref.watch(settingsProvider);
    final selectedId = ref.watch(selectedConversationIdProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildConversationDropdown(conversationsAsync, selectedId),
          ),
          const SizedBox(width: 8),
          settingsAsync.when(
            data: (settings) => _buildModelChip(settings),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationDropdown(
    AsyncValue<List<ChatConversation>> conversationsAsync,
    String? selectedId,
  ) {
    return conversationsAsync.when(
      data: (conversations) {
        if (conversations.isEmpty) {
          return const Text(
            'New conversation',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          );
        }
        final selected = conversations
            .where((c) => c.id == selectedId)
            .firstOrNull;
        return PopupMenuButton<String>(
          initialValue: selectedId,
          offset: const Offset(0, 32),
          constraints: const BoxConstraints(maxWidth: 280),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          color: AppColors.card,
          onSelected: (id) {
            if (id == '__new__') {
              ref.read(selectedConversationIdProvider.notifier).state = null;
            } else {
              ref.read(selectedConversationIdProvider.notifier).state = id;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem<String>(
              value: '__new__',
              height: 36,
              child: Row(
                children: [
                  Icon(Icons.add, size: 14, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'New conversation',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            ...conversations.map(
              (c) => PopupMenuItem<String>(
                value: c.id,
                height: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        Navigator.of(context).pop();
                        await ref
                            .read(conversationsProvider.notifier)
                            .deleteConversation(c.id);
                        if (ref.read(selectedConversationIdProvider) == c.id) {
                          ref
                                  .read(selectedConversationIdProvider.notifier)
                                  .state =
                              null;
                        }
                      },
                      child: const Icon(
                        Icons.delete_outline,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  selected?.title ?? 'New conversation',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.unfold_more,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildModelChip(ProviderSettings settings) {
    final config = PlatformConfig.findByType(settings.activeProvider);
    final model = settings.active.model;
    return InkWell(
      onTap: () => _showProviderModelSheet(settings),
      borderRadius: BorderRadius.circular(6),
      child: Tooltip(
        message: 'Change provider & model',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(config.icon, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                model.isNotEmpty ? model : 'No model',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.tune, size: 10, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _showProviderModelSheet(ProviderSettings settings) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => _ProviderModelSheet(
        settings: settings,
        onConfirm: (updated) {
          ref.read(settingsProvider.notifier).save(updated);
        },
      ),
    );
  }

  Widget _buildMessages(
    AsyncValue<List<ChatMessage>>? messagesAsync,
    bool isSending,
  ) {
    if (messagesAsync == null) {
      return const Center(
        child: Text(
          'Start a new conversation',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return messagesAsync.when(
      data: (messages) {
        _localMessages = List.of(messages);
        return _buildMessageList(messages, isSending);
      },
      loading: () {
        if (_localMessages.isNotEmpty) {
          return _buildMessageList(_localMessages, isSending);
        }
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      error: (e, _) => const Center(
        child: Text(
          'Error loading messages',
          style: TextStyle(color: AppColors.error, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildMessageList(List<ChatMessage> messages, bool isSending) {
    if (messages.isEmpty && !_isStreaming && _errorMessage.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    final showStreaming = _isStreaming && _streamingContent.isNotEmpty;
    final showThinking = isSending && !showStreaming;
    final showError = !_isStreaming && _errorMessage.isNotEmpty;
    final prefixCount = (showStreaming || showThinking || showError) ? 1 : 0;

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: prefixCount + messages.length,
      itemBuilder: (context, index) {
        if (index == 0 && showStreaming) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarkdownBody(
                        data: _streamingContent,
                        styleSheet: _MessageBubble._markdownStyle(context),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.primary.withValues(alpha: 0.6),
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

        if (index == 0 && showError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (index == 0 && showThinking) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Thinking...',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final msgIdx = index - prefixCount;
        final msg = messages[messages.length - 1 - msgIdx];
        return _MessageBubble(
          message: msg,
          isConsumed: _consumedToolIds.contains(msg.id),
          onCopy: () {
            Clipboard.setData(ClipboardData(text: msg.content));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copied to clipboard'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          onRegenerate: msg.role == 'assistant'
              ? () async {
                  final convId = ref.read(selectedConversationIdProvider);
                  if (convId == null) return;
                  final repo = ref.read(repositoryProvider);
                  await repo.chat.deleteMessage(msg.id);
                  ref.invalidate(chatMessagesProvider(convId));
                  final history = await repo.chat.listMessages(convId);
                  final lastUserMsg = history.lastWhere(
                    (m) => m.role == 'user',
                    orElse: () => msg,
                  );
                  unawaited(
                    _regenerateResponse(convId, lastUserMsg.content, history),
                  );
                }
              : null,
          onSelectChoice: (choice) {
            setState(() => _consumedToolIds.add(msg.id));
            _controller.text = choice;
            _sendMessage();
          },
          onConfirm: (approved, action) {
            setState(() => _consumedToolIds.add(msg.id));
            _controller.text = approved ? '승인: $action' : '거부: $action';
            _sendMessage();
          },
        );
      },
    );
  }

  Widget _buildInput(bool isSending) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _inputFocusNode,
              enabled: !isSending,
              maxLines: null,
              minLines: 1,
              style: const TextStyle(fontSize: 13, color: AppColors.foreground),
              decoration: const InputDecoration(
                hintText: 'Type a message... (Shift+Enter for new line)',
                hintStyle: TextStyle(fontSize: 12),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_isStreaming)
            IconButton(
              onPressed: _stopStreaming,
              icon: const Icon(Icons.stop, size: 18, color: AppColors.error),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.error.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          else
            IconButton(
              onPressed: isSending ? null : _sendMessage,
              icon: Icon(
                Icons.arrow_upward,
                size: 18,
                color: isSending ? AppColors.textMuted : AppColors.primary,
              ),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: isSending
                    ? AppColors.tertiary
                    : AppColors.primary.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProviderModelSheet extends ConsumerStatefulWidget {
  const _ProviderModelSheet({required this.settings, required this.onConfirm});

  final ProviderSettings settings;
  final void Function(ProviderSettings) onConfirm;

  @override
  ConsumerState<_ProviderModelSheet> createState() =>
      _ProviderModelSheetState();
}

class _ProviderModelSheetState extends ConsumerState<_ProviderModelSheet> {
  late ProviderType _selectedType;
  String _selectedModel = '';
  List<String> _models = [];
  bool _loadingModels = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.settings.activeProvider;
    _selectedModel = widget.settings.active.model;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_fetchModels()),
    );
  }

  String _currentModel() => widget.settings.configs[_selectedType]?.model ?? '';

  Future<void> _fetchModels() async {
    if (_loadingModels) return;
    setState(() => _loadingModels = true);

    try {
      final settings = widget.settings;
      String? apiKey;
      String? baseUrl;
      CustomApiFormat? format;

      final cfg = settings.configs[_selectedType];
      if (cfg is OpenAIConfig) {
        apiKey = cfg.apiKey;
      } else if (cfg is OllamaConfig) {
        baseUrl = cfg.baseUrl;
      } else if (cfg is CustomConfig) {
        baseUrl = cfg.baseUrl;
        apiKey = cfg.apiKey;
        format = cfg.apiFormat;
      }

      final models = await ModelFetcher.fetchModels(
        provider: _selectedType,
        apiKey: apiKey,
        baseUrl: baseUrl,
        apiFormat: format,
      );

      if (mounted) {
        setState(() {
          _models = models;
          _loadingModels = false;
        });
      }
    } on Object {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Provider & Model',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final configured = PlatformConfig.configured(widget.settings);
              if (configured.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No providers configured. Add one in Settings first.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }
              final validType =
                  configured.any((p) => p.providerType == _selectedType)
                  ? _selectedType
                  : configured.first.providerType;
              return DropdownButtonFormField<ProviderType>(
                value: validType,
                decoration: const InputDecoration(
                  labelText: 'Provider',
                  isDense: true,
                  prefixIcon: Icon(Icons.dns_outlined, size: 16),
                ),
                items: configured
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.providerType,
                        child: Text(
                          p.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedType = v;
                      _selectedModel = _currentModel();
                      _models = [];
                    });
                    _fetchModels();
                  }
                },
              );
            },
          ),
          const SizedBox(height: 12),
          if (_loadingModels)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            if (_models.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _models.contains(_selectedModel) ? _selectedModel : null,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  isDense: true,
                  prefixIcon: Icon(Icons.model_training, size: 16),
                ),
                items: _models
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          m,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedModel = v);
                },
              )
            else
              TextField(
                controller: TextEditingController(text: _selectedModel),
                decoration: InputDecoration(
                  labelText: 'Model',
                  isDense: true,
                  hintText: PlatformConfig.findByType(
                    _selectedType,
                  ).defaultModel,
                  prefixIcon: const Icon(Icons.model_training, size: 16),
                ),
                onChanged: (v) => _selectedModel = v,
              ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loadingModels ? null : _submit,
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final model = _selectedModel;
    final existing = widget.settings.configs[_selectedType];
    final ProviderConfig updatedConfig;
    switch (existing) {
      case OpenAIConfig():
        updatedConfig = existing.copyWith(
          model: model.isEmpty ? 'gpt-4o' : model,
        );
      case AnthropicConfig():
        updatedConfig = existing.copyWith(
          model: model.isEmpty ? 'claude-sonnet-4-20250514' : model,
        );
      case OllamaConfig():
        updatedConfig = existing.copyWith(
          model: model.isEmpty ? 'llama3' : model,
        );
      case CustomConfig():
        updatedConfig = existing.copyWith(model: model);
      case null:
        return;
    }
    final updated = widget.settings
        .withConfig(updatedConfig)
        .copyWith(activeProvider: _selectedType);
    widget.onConfirm(updated);
    Navigator.of(context).pop();
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.onCopy,
    this.onRegenerate,
    this.onSelectChoice,
    this.onConfirm,
    this.isConsumed = false,
  });

  final ChatMessage message;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;
  final void Function(String choice)? onSelectChoice;
  final void Function(bool approved, String action)? onConfirm;
  final bool isConsumed;

  @override
  Widget build(BuildContext context) {
    return switch (message.role) {
      'user' => _buildUserBubble(context),
      'assistant' => _buildAssistantBubble(context),
      'tool' => _buildToolCard(context),
      _ => const SizedBox.shrink(),
    };
  }

  static MarkdownStyleSheet _markdownStyle(BuildContext context) {
    return MarkdownStyleSheet(
      p: const TextStyle(
        fontSize: 13,
        height: 1.6,
        color: AppColors.foreground,
      ),
      h1: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.foreground,
        height: 1.4,
      ),
      h2: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.foreground,
        height: 1.4,
      ),
      h3: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.foreground,
        height: 1.4,
      ),
      h4: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.foreground,
      ),
      h5: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      h6: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      em: const TextStyle(
        fontStyle: FontStyle.italic,
        color: AppColors.textSecondary,
      ),
      strong: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.foreground,
      ),
      code: TextStyle(
        fontSize: 12,
        fontFamily: 'monospace',
        backgroundColor: AppColors.background,
        color: AppColors.primaryBright,
      ),
      a: const TextStyle(
        color: AppColors.primary,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.primary,
      ),
      blockquote: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.6,
      ),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      listBullet: const TextStyle(color: AppColors.primary, fontSize: 13),
      listIndent: 20,
      tableHead: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: AppColors.foreground,
      ),
      tableBody: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      tableBorder: TableBorder.all(color: AppColors.border, width: 0.5),
      tableHeadAlign: TextAlign.center,
      tableCellsPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      codeblockDecoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onCopy != null)
          _ActionButton(
            icon: Icons.copy_outlined,
            tooltip: 'Copy',
            onTap: onCopy!,
          ),
        if (message.role == 'assistant' && onRegenerate != null) ...[
          const SizedBox(width: 2),
          _ActionButton(
            icon: Icons.refresh,
            tooltip: 'Regenerate',
            onTap: onRegenerate!,
          ),
        ],
      ],
    );
  }

  Widget _buildUserBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: const TextStyle(fontSize: 13, color: AppColors.foreground),
            ),
            const SizedBox(height: 4),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: message.content,
              styleSheet: _markdownStyle(context),
            ),
            const SizedBox(height: 4),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(BuildContext context) {
    final toolName = message.toolName ?? 'tool';

    if (toolName == 'present_choices' && onSelectChoice != null) {
      return _buildChoiceCard(context);
    }

    if (toolName == 'confirm_action' && onConfirm != null) {
      return _buildConfirmCard(context);
    }

    return _buildRichToolCard(context, toolName);
  }

  Widget _buildChoiceCard(BuildContext context) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.content) as Map<String, dynamic>;
    } on Object {
      data = {};
    }
    final title = data['title'] as String? ?? '선택해주세요';
    final options =
        (data['options'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        [];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isConsumed
                ? AppColors.border
                : AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConsumed ? Icons.check_circle_outline : Icons.list_alt,
                  size: 14,
                  color: isConsumed
                      ? AppColors.success
                      : AppColors.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isConsumed)
              Text(
                '선택 완료',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: options.map((option) {
                  return ActionChip(
                    label: Text(option, style: const TextStyle(fontSize: 12)),
                    onPressed: () => onSelectChoice?.call(option),
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmCard(BuildContext context) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.content) as Map<String, dynamic>;
    } on Object {
      data = {};
    }
    final title = data['title'] as String? ?? '확인 필요';
    final description = data['description'] as String? ?? '';
    final action = data['action'] as String? ?? '';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isConsumed
                ? AppColors.border
                : AppColors.warning.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConsumed ? Icons.check_circle_outline : Icons.help_outline,
                  size: 14,
                  color: isConsumed ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (isConsumed)
              Text(
                '처리됨',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onConfirm?.call(true, action),
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('승인', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onConfirm?.call(false, action),
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('거부', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRichToolCard(BuildContext context, String toolName) {
    final content = message.content;

    Map<String, dynamic>? json;
    try {
      json = jsonDecode(content) as Map<String, dynamic>;
    } on Object {
      json = null;
    }

    final isSuccess = json?['success'] == true;
    final isError = json?['error'] != null;
    final messageText =
        json?['message'] as String? ??
        json?['error'] as String? ??
        (content.length > 200 ? '${content.substring(0, 200)}...' : content);

    final statusIcon = isError
        ? Icons.error_outline
        : isSuccess
        ? Icons.check_circle_outline
        : Icons.build_outlined;
    final statusColor = isError
        ? AppColors.error
        : isSuccess
        ? AppColors.success
        : AppColors.textMuted;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  toolName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              messageText,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: AppColors.textMuted),
        ),
      ),
    );
  }
}
