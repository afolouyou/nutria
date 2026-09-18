import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/pantry_provider.dart';
import '../theme/app_theme.dart';
import '../models/message.dart';
import '../widgets/app_background.dart';
import '../widgets/plan_popup.dart';
import '../widgets/recipe_card.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _drawerKey = GlobalKey<ScaffoldState>();
  bool _llmModeSmart = false;
  String _recipeNotes = '';
  late AnimationController _suggestAnimCtrl;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _suggestAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final chat = context.read<ChatProvider>();
        chat.loadConversations();
        chat.loadRemainingRecipes();
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) setState(() => _showSuggestions = true);
        });
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _suggestAnimCtrl.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _inputCtrl.clear();
    setState(() => _showSuggestions = false);
    context.read<ChatProvider>().sendMessage(text.trim(), smart: _llmModeSmart);
  }

  Future<void> _requestRecipe(ChatProvider chat) async {
    if (chat.isStreaming || chat.generatingRecipe) return;

    if (!chat.softLimits && chat.menusRemaining == 0) {
      showPlansPopup(context);
      return;
    }

    final notes = await _showRecipeSheet(chat);
    if (notes == null || !mounted) return;

    setState(() => _recipeNotes = notes);
    await _runRecipeGeneration(chat);
  }

  Future<String?> _showRecipeSheet(ChatProvider chat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.greenDark : AppColors.green;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final orange = AppColors.orange;
    final remaining = chat.menusRemaining;
    final remainingOk = chat.softLimits || remaining != 0;
    final remainingText = remaining < 0 ? '—' : '$remaining';

    var draft = _recipeNotes;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.restaurant_menu, size: 28, color: orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gerar receita com a despensa',
                              style: GoogleFonts.poppins(
                                  fontSize: 17, fontWeight: FontWeight.w700, color: text),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'A IA monta uma refeição com os itens que você tem em casa.',
                              style: GoogleFonts.poppins(fontSize: 12, color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: remainingOk
                          ? accent.withValues(alpha: 0.08)
                          : AppColors.danger.withValues(alpha: 0.10),
                      border: Border.all(
                        color: remainingOk
                            ? accent.withValues(alpha: 0.4)
                            : AppColors.danger.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          remainingOk ? Icons.event_available : Icons.error_outline,
                          size: 18,
                          color: remainingOk ? accent : AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            remainingOk
                                ? 'Receitas restantes nesta semana: $remainingText'
                                : 'Você já usou suas receitas da semana. Escolha um plano para liberar mais.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: remainingOk ? accent : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Notas (opcional)',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600, color: text),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    autofocus: false,
                    controller: TextEditingController(text: draft),
                    onChanged: (v) => draft = v,
                    maxLines: 3,
                    minLines: 2,
                    style: GoogleFonts.poppins(fontSize: 14, color: text),
                    decoration: InputDecoration(
                      hintText: 'Ex.: sem cebola, sem lactose, pouco sal...',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 14, color: text.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: surface.withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accent, width: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: remainingOk
                        ? () => Navigator.pop(ctx2, draft.trim())
                        : () {
                            Navigator.pop(ctx2);
                            if (mounted) showPlansPopup(context);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: remainingOk ? accent : AppColors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        remainingOk ? 'Gerar receita' : 'Ver planos',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _runRecipeGeneration(ChatProvider chat) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Gerando receita com sua despensa...'),
          backgroundColor: Colors.black87,
          duration: Duration(days: 1),
        ),
      );

    final data = await chat.generateRecipe(notes: _recipeNotes.isEmpty ? null : _recipeNotes);
    messenger.removeCurrentSnackBar();

    if (!mounted) return;

    if (data == null) {
      final err = chat.recipeError;
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(err != null && !err.contains('Limite')
            ? err
            : 'Limite de receitas da semana atingido.'),
        backgroundColor: AppColors.danger,
      ));
      if (err == null || err.contains('Limite')) {
        if (mounted) showPlansPopup(context);
      }
      return;
    }

    final consumed = data['consumed'];
    final consumedSummary = consumed is List
        ? consumed
            .whereType<Map>()
            .map((c) => '${c['name']} (${c['quantity']}${c['unit']})')
            .join(', ')
        : '';

    final lowCount =
        data['low_stock'] is List ? (data['low_stock'] as List).length : 0;
    final lowOut =
        lowCount > 0 ? (data['low_stock'] as List).whereType<Map>().where((e) => e['out_of_stock'] == true).length : 0;

    final message = consumedSummary.isEmpty
        ? 'Receita gerada! Confira abaixo.'
        : 'Receita pronta! Itens consumidos: $consumedSummary';
    final extra =
        lowCount > 0 ? ' | Acabando (${lowCount - lowOut}), sem estoque ($lowOut)' : '';

    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      content: Text('$message$extra'),
      backgroundColor: const Color(0xFF1B6A26),
    ));
    context.read<PantryProvider>().loadItems();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pantryNote = chat.pantryNote;
    if (pantryNote != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(pantryNote),
            backgroundColor: const Color(0xFF1B6A26),
            duration: const Duration(seconds: 2),
          ));
        context.read<ChatProvider>().clearPantryNote();
      });
    }
    final accent = isDark ? AppColors.greenDark : AppColors.green;
    final accentHover = isDark ? AppColors.greenHoverDark : AppColors.greenHover;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final surface2 = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final orange = AppColors.orange;
    final orangeSoft = isDark ? AppColors.orangeSoftDark : AppColors.orangeSoftLight;
    final accentSoft = isDark ? AppColors.accentSoftDark : AppColors.accentSoftLight;

    if (chat.isStreaming) _scrollToBottom();

    return Scaffold(
      key: _drawerKey,
      backgroundColor: Colors.transparent,
      drawer: _buildDrawer(context, chat, isDark, accent, accentSoft, surface, border),
      body: Stack(
        children: [
          Positioned.fill(
            child: AppBackground(isDark: isDark),
          ),
          Positioned.fill(
            child: Column(
              children: [
                _buildHeader(context, isDark),
                Expanded(
                  child: chat.messages.isEmpty && !chat.isStreaming
                      ? _buildWelcome(context, chat, isDark, accent, muted, text, border, surface, orange)
                      : _buildMessages(chat, isDark, accent, muted, text, border, surface),
                ),
                _buildInputArea(context, chat, isDark, accent, accentHover, muted, text, border, surface, surface2, orange, orangeSoft, accentSoft),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.topFade(isDark),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(Icons.menu, color: AppColors.onImage(isDark), size: 22),
                  onPressed: () => _drawerKey.currentState?.openDrawer(),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              Text(
                'Chat',
                style: GoogleFonts.poppins(
                  color: AppColors.onImage(isDark),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  shadows: isDark
                      ? [const Shadow(blurRadius: 3, color: Colors.black45)]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, ChatProvider chat, bool isDark, Color accent, Color accentSoft, Color surface, Color border) {
    return Drawer(
      width: 300,
      backgroundColor: surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: GestureDetector(
                onTap: () {
                  chat.newChat();
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: accentSoft,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Nova conversa',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: chat.conversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Nenhuma conversa ainda.',
                          style: GoogleFonts.poppins(
                            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: chat.conversations.length,
                      itemBuilder: (context, index) {
                        final conv = chat.conversations[index];
                        final isActive = conv.id == chat.currentConversationId;
                        return GestureDetector(
                          onTap: () {
                            chat.openConversation(conv.id);
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: isActive ? accentSoft : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              conv.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: isDark ? AppColors.darkText : AppColors.lightText,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome(BuildContext context, ChatProvider chat, bool isDark, Color accent, Color muted, Color text, Color border, Color surface, Color orange) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 18),
            Text(
              'Olá! Eu sou o NutrIA.',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.02,
                color: text,
                shadows: isDark
                    ? [const Shadow(blurRadius: 6, color: Colors.black54)]
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            if (!_showSuggestions)
              SizedBox(
                width: 120,
                child: Column(
                  children: [
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: CustomPaint(
                        painter: _SuggestionLoaderPainter(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sugerindo opções:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...chat.suggestions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _showSuggestions = false);
                        _send(s);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: surface,
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                  s,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                        ),
                      ),
                    ),
                  )),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages(ChatProvider chat, bool isDark, Color accent, Color muted, Color text, Color border, Color surface) {
    final showError = chat.streamError != null && !chat.isStreaming;
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: chat.messages.length +
          (chat.isStreaming ? 1 : 0) +
          (showError ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chat.messages.length && chat.isStreaming) {
          return _buildStreamingWidget(chat, isDark, accent, muted, text, border, surface);
        }
        if (showError && index == chat.messages.length) {
          return _buildStreamErrorBubble(chat.streamError!, isDark, text, border);
        }
        return _buildMessageBubble(chat.messages[index], isDark, accent, text, border, surface);
      },
    );
  }

  Widget _buildStreamErrorBubble(String message, bool isDark, Color text, Color border) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        margin: const EdgeInsets.only(top: 6, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isDark, Color accent, Color text, Color border, Color surface) {
    final isUser = msg.isUser;

    if (msg.card != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RecipeCard(recipe: msg.card!),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? accent : surface,
          border: isUser ? null : Border.all(color: border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
        ),
        child: isUser
            ? Text(
                msg.text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white,
                ),
              )
            : MarkdownBody(
                data: msg.text,
                selectable: true,
                softLineBreak: false,
                styleSheet: MarkdownStyleSheet(
                  p: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  strong: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  listBullet: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  listIndent: 20,
                  tableBorder: TableBorder.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  tableHead: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  tableBody: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  tableColumnWidth: const FlexColumnWidth(),
                  blockquoteDecoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: accent, width: 3)),
                  ),
                  blockquote: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStreamingWidget(ChatProvider chat, bool isDark, Color accent, Color muted, Color text, Color border, Color surface) {
    if (chat.thinkingTitle.isNotEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💭', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Pensando: ${chat.thinkingTitle}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (chat.streamingText.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _loadingDot(0, muted),
              const SizedBox(width: 4),
              _loadingDot(1, muted),
              const SizedBox(width: 4),
              _loadingDot(2, muted),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: const Radius.circular(4),
            bottomRight: const Radius.circular(14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: MarkdownBody(
                data: chat.streamingText,
                styleSheet: MarkdownStyleSheet(
                  p: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  strong: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 3),
            _StreamingCursor(color: isDark ? AppColors.darkText : AppColors.lightText),
          ],
        ),
      ),
    );
  }

  Widget _loadingDot(int i, Color color) {
    return _PulsingDot(delayMs: i * 180, color: color);
  }

  Widget _buildInputArea(
    BuildContext context,
    ChatProvider chat,
    bool isDark,
    Color accent,
    Color accentHover,
    Color muted,
    Color text,
    Color border,
    Color surface,
    Color surface2,
    Color orange,
    Color orangeSoft,
    Color accentSoft,
  ) {
    final remaining = chat.menusRemaining;
    final remainingText = remaining < 0 ? '?' : '$remaining';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.bottomFade(isDark),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode toggle bar
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: surface.withValues(alpha: 0.75),
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Receitas restantes: ',
                          style: GoogleFonts.poppins(fontSize: 12, color: muted, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          remainingText,
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: orange),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: (chat.isStreaming || chat.generatingRecipe) ? null : () => _requestRecipe(chat),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: (chat.isStreaming || chat.generatingRecipe) ? 0.45 : 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: orange,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (chat.generatingRecipe)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            else
                              const Icon(Icons.restaurant_menu, size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              'Receita',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _llmModeSmart = !_llmModeSmart),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _llmModeSmart ? orangeSoft : accentSoft,
                        border: Border.all(color: _llmModeSmart ? orange : accent),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_llmModeSmart)
                            Icon(Icons.auto_awesome, size: 14, color: orange)
                          else
                            Icon(Icons.bolt, size: 14, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            _llmModeSmart ? 'Smart' : 'Básico',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _llmModeSmart ? orange : accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Input pill
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _inputCtrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (v) => _send(v),
                style: GoogleFonts.poppins(fontSize: 15, color: text),
                decoration: InputDecoration(
                  hintText: 'Pergunte ao NutrIA...',
                  hintStyle: GoogleFonts.poppins(color: muted),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: accent, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  suffixIcon: GestureDetector(
                    onTap: chat.isStreaming ? null : () => _send(_inputCtrl.text),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        chat.isStreaming ? Icons.stop : Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(maxWidth: 52, maxHeight: 52),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamingCursor extends StatefulWidget {
  final Color color;
  const _StreamingCursor({required this.color});

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl.drive(Tween(begin: 0.35, end: 0.0).chain(CurveTween(curve: const _PulseCurve()))),
      child: Container(
        width: 8,
        height: 16,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _PulseCurve extends Curve {
  const _PulseCurve();
  @override
  double transformInternal(double t) {
    return t < 0.5 ? 0.0 : 1.0;
  }
}

class _PulsingDot extends StatefulWidget {
  final int delayMs;
  final Color color;
  const _PulsingDot({required this.delayMs, required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delay = widget.delayMs / 1200.0;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = (_ctrl.value + delay) % 1.0;
        final opacity = 0.3 + (t < 0.5 ? t * 2 * 0.7 : (1 - t) * 2 * 0.7);
        return Opacity(
          opacity: opacity.clamp(0.3, 1.0),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionLoaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = 12.0;
    final dotR = 4.0;
    final paint = Paint()..color = AppColors.orange;

    for (int i = 0; i < 3; i++) {
      final dx = cx + r * 0.7 * (i == 0 ? -0.6 : i == 2 ? 0.6 : 0);
      final dy = cy + r * 0.7 * (i == 1 ? 0.6 : i == 0 ? -0.6 : 0);
      canvas.drawCircle(Offset(dx, dy), dotR, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
