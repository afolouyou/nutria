import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/pantry_provider.dart';
import '../theme/app_theme.dart';
import '../models/pantry_item.dart';
import '../widgets/app_background.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  String _unit = 'kg';
  String _category = 'Outros';

  static const _units = ['g', 'kg', 'ml', 'l', 'un'];
  static const _categories = ['Mantimentos', 'Refrigerados', 'Hortifruti', 'Temperos', 'Outros'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PantryProvider>().loadItems();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.greenDark : AppColors.green;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final surface2 = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final canAdd = _nameCtrl.text.trim().isNotEmpty && _qtyCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: AppBackground(isDark: isDark),
          ),
          Positioned.fill(
            child: Column(
              children: [
                _buildHeader(isDark),
                Expanded(
                  child: pantry.isLoading
                      ? Center(child: CircularProgressIndicator(color: accent))
                      : _buildBody(pantry, isDark, accent, text, muted, surface, surface2, border, canAdd),
                ),
              ],
            ),
          ),
          // Bottom gradient behind nav
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: AppColors.bottomFade(isDark),
                ),
              ),
            ),
          ),
          // Edit modal overlay
          if (pantry.items.isNotEmpty)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                child: const SizedBox.expand(),
                onTap: () {},
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
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
        child: Align(
          alignment: Alignment.center,
          child: Text(
            'Despensa',
            style: GoogleFonts.poppins(
              color: AppColors.onImage(isDark),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              shadows: isDark
                  ? [const Shadow(blurRadius: 3, color: Colors.black45)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    PantryProvider pantry,
    bool isDark,
    Color accent,
    Color text,
    Color muted,
    Color surface,
    Color surface2,
    Color border,
    bool canAdd,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle
          Text(
            'Guarde o que você tem em casa, com quantidades, para controlar seus alimentos.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.onImageMuted(isDark),
              shadows: isDark
                  ? [const Shadow(blurRadius: 3, color: Colors.black45)]
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // Inline form pill
          _buildFormPill(isDark, accent, text, muted, surface, surface2, border, canAdd),

          const SizedBox(height: 16),

          // Count
          Text(
            'ITENS (${pantry.items.length})',
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.04,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.75)
                  : AppColors.lightMuted,
              shadows: isDark
                  ? [const Shadow(blurRadius: 3, color: Colors.black45)]
                  : null,
            ),
          ),
          const SizedBox(height: 8),

          if (pantry.items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 28),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.7),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.3) : border,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Sua despensa esta vazia. Adicione o primeiro item acima.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? Colors.white.withValues(alpha: 0.8) : muted,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...pantry.items.map((item) => _buildItemTile(
                  item, pantry, isDark, accent, text, muted, surface, border,
                )),
        ],
      ),
    );
  }

  Widget _buildFormPill(bool isDark, Color accent, Color text, Color muted, Color surface, Color surface2, Color border, bool canAdd) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [surface, surface2]),
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Name row + add button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  maxLength: 30,
                  buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
                  style: GoogleFonts.poppins(fontSize: 15, color: text),
                  decoration: InputDecoration(
                    hintText: 'Ex.: arroz, ovos, tomate...',
                    hintStyle: GoogleFonts.poppins(color: muted),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: canAdd ? () => _addItem() : null,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: canAdd ? accent : accent.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          // Fields row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _qtyField(muted, text),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _unitSelect(muted, text),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _catSelect(muted, text),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyField(Color muted, Color text) {
    return TextField(
      controller: _qtyCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        LengthLimitingTextInputFormatter(4),
      ],
      style: GoogleFonts.poppins(fontSize: 14, color: text),
      decoration: InputDecoration(
        hintText: 'Qtd.',
        hintStyle: GoogleFonts.poppins(color: muted),
        filled: true,
        fillColor: Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.transparent),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  Widget _unitSelect(Color muted, Color text) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.transparent),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButton<String>(
        value: _unit,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        style: GoogleFonts.poppins(fontSize: 14, color: text),
        items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
        onChanged: (v) => setState(() => _unit = v ?? 'kg'),
      ),
    );
  }

  Widget _catSelect(Color muted, Color text) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.transparent),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButton<String>(
        value: _category,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        style: GoogleFonts.poppins(fontSize: 13, color: text),
        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => _category = v ?? 'Outros'),
      ),
    );
  }

  Widget _buildItemTile(PantryItem item, PantryProvider pantry, bool isDark, Color accent, Color text, Color muted, Color surface, Color border) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit}',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: accent),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.category,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: accent),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _openEdit(item),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              child: Icon(Icons.edit, size: 15, color: muted),
            ),
          ),
          GestureDetector(
            onTap: () => pantry.deleteItem(item.id),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              child: const Text('✕', style: TextStyle(fontSize: 16, color: AppColors.danger)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem() async {
    final name = _nameCtrl.text.trim();
    final qtyStr = _qtyCtrl.text.trim().replaceAll(',', '.');
    final qty = double.tryParse(qtyStr);
    if (name.isEmpty || qty == null || qty <= 0) return;

    final ok = await context.read<PantryProvider>().addItem(name, qty, _unit, _category);
    if (ok) {
      _nameCtrl.clear();
      _qtyCtrl.clear();
      setState(() {
        _unit = 'kg';
        _category = 'Outros';
      });
    }
  }

  void _openEdit(PantryItem item) {
    final editNameCtrl = TextEditingController(text: item.name);
    final editQtyCtrl = TextEditingController(text: item.quantity.truncateToDouble() == item.quantity ? item.quantity.toInt().toString() : item.quantity.toString());
    String editUnit = item.unit;
    String editCat = item.category;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.greenDark : AppColors.green;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Editar item',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: text),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('✕', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: editNameCtrl,
                    style: GoogleFonts.poppins(fontSize: 15, color: text),
                    decoration: InputDecoration(
                      hintText: 'Ex.: arroz, ovos, tomate...',
                      hintStyle: GoogleFonts.poppins(color: muted),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(borderSide: BorderSide(color: border)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: border)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accent, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: editQtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            LengthLimitingTextInputFormatter(4),
                          ],
                          style: GoogleFonts.poppins(fontSize: 14, color: text),
                          decoration: InputDecoration(
                            hintText: 'Qtd.',
                            hintStyle: GoogleFonts.poppins(color: muted),
                            isDense: true,
                            border: OutlineInputBorder(borderSide: BorderSide(color: border)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: border)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accent, width: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: editUnit,
                          isExpanded: true,
                          underline: const SizedBox(),
                          style: GoogleFonts.poppins(fontSize: 14, color: text),
                          items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (v) => setDialogState(() => editUnit = v ?? 'kg'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButton<String>(
                          value: editCat,
                          isExpanded: true,
                          underline: const SizedBox(),
                          style: GoogleFonts.poppins(fontSize: 13, color: text),
                          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setDialogState(() => editCat = v ?? 'Outros'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = editNameCtrl.text.trim();
                        final qtyStr = editQtyCtrl.text.trim().replaceAll(',', '.');
                        final qty = double.tryParse(qtyStr);
                        if (name.isEmpty || qty == null || qty <= 0) return;
                        await context.read<PantryProvider>().updateItem(item.id, name, qty, editUnit, editCat);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Salvar alteracoes', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
