import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../core/sse_client.dart';
import '../core/storage.dart';
import '../models/message.dart';
import '../models/conversation.dart';

class ChatProvider extends ChangeNotifier {
  final _api = ApiClient();
  final _sse = SSEClient();
  final _storage = SecureStorage();
  final _cache = AppCache.instance;

  List<Message> _messages = [];
  List<Conversation> _conversations = [];
  String? _currentConversationId;
  bool _isStreaming = false;
  String _streamingText = '';
  String _thinkingTitle = '';
  bool _showSuggestions = true;
  int _menusRemaining = -1;
  int _chatRemaining = -1;
  String _plan = 'free';
  bool _softLimits = true;
  StreamSubscription<SSEEvent>? _streamSub;
  bool _generatingRecipe = false;
  String? _recipeError;
  String? _pantryNote;
  String? _streamError;
  Map<String, dynamic>? _pendingRecipeCard;

  List<Message> get messages => _messages;
  List<Conversation> get conversations => _conversations;
  String? get currentConversationId => _currentConversationId;
  bool get isStreaming => _isStreaming;
  String get streamingText => _streamingText;
  String get thinkingTitle => _thinkingTitle;
  bool get showSuggestions => _showSuggestions && _messages.isEmpty && !_isStreaming;
  int get menusRemaining => _menusRemaining;
  int get chatRemaining => _chatRemaining;
  String get plan => _plan;
  bool get softLimits => _softLimits;
  bool get generatingRecipe => _generatingRecipe;
  String? get recipeError => _recipeError;
  String? get pantryNote => _pantryNote;
  String? get streamError => _streamError;

  void clearPantryNote() {
    if (_pantryNote == null) return;
    _pantryNote = null;
    notifyListeners();
  }

  final List<String> suggestions = const [
    'Analise meu almoço: arroz, feijão, frango grelhado e salada',
    'Crie um plano alimentar para emagrecer 3kg',
    'O que devo comer no café da manhã?',
  ];

  Future<void> loadConversations() async {
    final cached = await _readCachedConversations();
    if (cached != null) {
      _conversations = cached;
      notifyListeners();
    }
    try {
      final data = await _api.getConversations();
      _conversations = data
          .whereType<Map<String, dynamic>>()
          .map(Conversation.fromJson)
          .toList();
      _conversations.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(0);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
      _cache.writeJson(_cache.keyConversations(),
          _conversations.map((c) => c.toJson()).toList());
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadRemainingRecipes() async {
    final cachedRemaining = await _readCachedRemaining();
    if (cachedRemaining != null) {
      _menusRemaining = cachedRemaining;
      notifyListeners();
    }
    try {
      final data = await _api.getPlan();
      _plan = data['plan']?.toString() ?? 'free';
      _chatRemaining = _asInt(data['chat_remaining']);
      _menusRemaining = _asInt(data['recipe_remaining']);
      _softLimits = data['soft_limits'] == true;
      _cache.writeJson(_cache.keyRecipes(), {'remaining': _menusRemaining});
      notifyListeners();
    } catch (_) {}
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return -1;
  }

  Future<void> openConversation(String id) async {
    try {
      final data = await _api.getConversation(id);
      final conv = Conversation.fromJson(data);
      _currentConversationId = conv.id;
      _messages = conv.messages ?? [];
      _showSuggestions = false;
      await _updateCachedConversation(conv);
      notifyListeners();
    } catch (_) {
      final cachedConv = await _readCachedConversation(id);
      if (cachedConv != null) {
        _currentConversationId = cachedConv.id;
        _messages = cachedConv.messages ?? [];
        _showSuggestions = false;
        notifyListeners();
      }
    }
  }

  void newChat() {
    _currentConversationId = null;
    _messages = [];
    _streamingText = '';
    _thinkingTitle = '';
    _streamError = null;
    _showSuggestions = true;
    notifyListeners();
  }

  Future<void> sendMessage(String text, {bool smart = false}) async {
    if (text.trim().isEmpty || _isStreaming) return;

    _messages.add(Message(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      text: text,
      createdAt: DateTime.now(),
    ));
    _showSuggestions = false;
    _isStreaming = true;
    _streamingText = '';
    _thinkingTitle = '';
    _streamError = null;
    notifyListeners();

    final token = await _storage.getToken() ?? '';

    try {
      final stream = _sse.streamChat(
        token,
        text,
        conversationId: _currentConversationId,
        mode: smart ? 'smart' : 'fast',
      );

      _streamSub = stream.listen(
        (event) {
          switch (event.type) {
            case 'chunk':
              _streamingText += event.text ?? '';
              _thinkingTitle = '';
              notifyListeners();
            case 'thinking':
              if (_streamingText.isEmpty && _thinkingTitle.isEmpty) {
                _thinkingTitle = event.text ?? 'Pensando...';
                notifyListeners();
              }
            case 'pantry_updated':
              _pantryNote = 'Despensa atualizada pela IA';
              notifyListeners();
            case 'recipe_ready':
              if (event.data?['recipe'] is Map<String, dynamic>) {
                _streamingText = _streamingText.isNotEmpty
                    ? _streamingText
                    : 'Receita pronta! Confira os detalhes abaixo.';
                _pendingRecipeCard = event.data?['recipe'];
                notifyListeners();
              }
            case 'done':
              final data = event.data;
              final newConvId = data?['conversation_id']?.toString();
              if (newConvId != null && newConvId.isNotEmpty) {
                _currentConversationId = newConvId;
              }
              final serverText = data?['assistant_message']?['text']?.toString();
              if (serverText != null && serverText.isNotEmpty) {
                _streamingText = serverText;
              }
              final serverPlan = data?['plan']?.toString();
              if (serverPlan != null && serverPlan.isNotEmpty) {
                _plan = serverPlan;
              }
              final chatRemaining = data?['chat_remaining'];
              if (chatRemaining is int) {
                _chatRemaining = chatRemaining;
              } else if (chatRemaining == null) {
                _chatRemaining = -1;
              }
              _finalizeResponse();
            case 'error':
              _streamError = event.text ?? 'Não foi possível concluir a solicitação. Tente novamente.';
              _pendingRecipeCard = null;
              notifyListeners();
              _finalizeResponse();
          }
        },
        onDone: () => _finalizeResponse(),
        onError: (e) {
          _streamError = 'Não foi possível conectar ao servidor. Tente novamente. ($e)';
          _pendingRecipeCard = null;
          notifyListeners();
          _finalizeResponse();
        },
      );
    } catch (e) {
      _streamError = 'Não foi possível enviar a mensagem. Tente novamente. ($e)';
      _pendingRecipeCard = null;
      notifyListeners();
      _finalizeResponse();
    }
  }

  void _finalizeResponse() {
    if (_streamingText.isNotEmpty) {
      _messages.add(Message(
        id: 'assistant_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        text: _streamingText,
        createdAt: DateTime.now(),
        card: _pendingRecipeCard,
      ));
    }
    final finalizedConvId = _currentConversationId;
    _streamingText = '';
    _thinkingTitle = '';
    _isStreaming = false;
    _streamSub = null;
    _pendingRecipeCard = null;
    if (finalizedConvId != null && finalizedConvId.isNotEmpty) {
      _updateCachedConversation(Conversation(
        id: finalizedConvId,
        title: _messages.isNotEmpty ? _messages.first.text : 'Chat',
        messages: List.of(_messages),
      ));
    }
    _cacheConversationsFromMessages();
    loadConversations();
    loadRemainingRecipes();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> generateRecipe({String? notes}) async {
    if (_generatingRecipe || _isStreaming) return null;
    _generatingRecipe = true;
    _recipeError = null;
    notifyListeners();

    try {
      final data = await _api.post('/pantry/recipes', {
        'notes': notes ?? '',
        'conversation_id': _currentConversationId,
      });

      final suggestions = (data['suggestions'] ?? '').toString();
      final rawCard = data['recipe'];
      final card = rawCard is Map<String, dynamic> ? rawCard : null;

      if (suggestions.isEmpty && card == null) {
        _recipeError = 'Não consegui montar a receita. Tente novamente.';
        return null;
      }

      final serverConversationId = data['conversation_id']?.toString();
      if (serverConversationId != null && serverConversationId.isNotEmpty) {
        _currentConversationId = serverConversationId;
      }

      _messages.add(Message(
        id: 'recipe_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        text: suggestions,
        createdAt: DateTime.now(),
        card: card,
      ));
      _showSuggestions = false;
      if (_menusRemaining > 0) {
        _menusRemaining -= 1;
        await _cache.writeJson(_cache.keyRecipes(), {'remaining': _menusRemaining});
      }
      _cacheConversationsFromMessages();
      loadConversations();
      loadRemainingRecipes();
      notifyListeners();
      return data;
    } catch (e) {
      _recipeError = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return null;
    } finally {
      _generatingRecipe = false;
      notifyListeners();
    }
  }

  void cancelStream() {
    _streamSub?.cancel();
    _finalizeResponse();
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _api.deleteConversation(id);
      _conversations.removeWhere((c) => c.id == id);
      if (_currentConversationId == id) newChat();
      _cache.writeJson(
        _cache.keyConversations(),
        _conversations.map((c) => c.toJson()).toList(),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<List<Conversation>?> _readCachedConversations() async {
    final raw = await _cache.readJsonList<Map<String, dynamic>>(_cache.keyConversations());
    if (raw == null) return null;
    try {
      return raw.map(Conversation.fromJson).toList();
    } catch (_) {
      return null;
    }
  }

  Future<Conversation?> _readCachedConversation(String id) async {
    final conversations = await _readCachedConversations();
    if (conversations == null) return null;
    for (final c in conversations) {
      if (c.id == id && c.messages != null) return c;
    }
    return null;
  }

  Future<void> _updateCachedConversation(Conversation conv) async {
    final conversations = await _readCachedConversations() ?? [];
    final index = conversations.indexWhere((c) => c.id == conv.id);
    if (index >= 0) {
      conversations[index] = conv;
    } else {
      conversations.add(conv);
    }
    await _cache.writeJson(
      _cache.keyConversations(),
      conversations.map((c) => c.toJson()).toList(),
    );
  }

  Future<void> _cacheConversationsFromMessages() async {
    if (_currentConversationId == null || _messages.isEmpty) return;
    await _updateCachedConversation(Conversation(
      id: _currentConversationId!,
      title: _messages.first.text,
      messages: List.of(_messages),
    ));
  }

  Future<int?> _readCachedRemaining() async {
    final data = await _cache.readJson<Map<String, dynamic>>(_cache.keyRecipes());
    if (data == null) return null;
    final value = data['remaining'];
    if (value is num) return value.toInt();
    return null;
  }
}
