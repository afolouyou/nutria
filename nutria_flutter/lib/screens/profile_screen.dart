import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/plan_popup.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String? _avatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty) return null;
    if (avatar.startsWith('http')) return avatar;
    return 'https://nutria.shares.zrok.io$avatar';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDark;
    final accent = isDark ? AppColors.greenDark : AppColors.green;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final surface2 = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final user = auth.user;
    final initial = (user != null && user.name.isNotEmpty) ? user.name[0].toLowerCase() : '?';

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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
                    child: Column(
                      children: [
                        // Profile card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                          decoration: BoxDecoration(
                            color: surface2,
                            border: Border.all(color: border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              // Avatar
                              GestureDetector(
                                onTap: () => _showAvatarDialog(context, user?.avatar, initial, isDark, accent),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 96,
                                      height: 96,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: (user?.avatar == null || user!.avatar!.isEmpty)
                                            ? LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [accent, accent.withValues(alpha: 0.7)],
                                              )
                                            : null,
                                        image: _avatarUrl(user?.avatar) != null
                                            ? DecorationImage(
                                                image: NetworkImage(_avatarUrl(user!.avatar)!),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: (user?.avatar == null || user!.avatar!.isEmpty)
                                          ? Center(
                                              child: Text(
                                                initial,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 38,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: surface, width: 3),
                                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
                                        ),
                                        child: const Icon(Icons.edit, size: 15, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                user?.name ?? '',
                                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: text),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                style: GoogleFonts.poppins(fontSize: 13, color: muted),
                              ),
                              const SizedBox(height: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  (user?.provider ?? 'email').toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.04,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Theme toggle row
                        _buildThemeRow(context, theme, isDark, text, muted, surface, border),

                        const SizedBox(height: 12),

                        // Plans row
                        _buildPlansRow(context, isDark, text, muted, surface, border),

                        const SizedBox(height: 12),

                        // Logout
                        _buildLogoutButton(context, isDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom gradient
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
            'Perfil',
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

  Widget _buildThemeRow(BuildContext context, ThemeProvider theme, bool isDark, Color text, Color muted, Color surface, Color border) {
    return GestureDetector(
      onTap: () => theme.toggle(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: muted, size: 18),
            const SizedBox(width: 10),
            Text(
              'Modo escuro',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: text),
            ),
            const Spacer(),
            Text(
              isDark ? 'Ativado' : 'Desativado',
              style: GoogleFonts.poppins(fontSize: 13, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlansRow(BuildContext context, bool isDark, Color text, Color muted, Color surface, Color border) {
    return GestureDetector(
      onTap: () => showPlansPopup(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.workspace_premium, color: isDark ? AppColors.goldDark : AppColors.gold, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NutrIA Premium & Gold',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: text),
                  ),
                  Text(
                    'Veja os planos disponíveis',
                    style: GoogleFonts.poppins(fontSize: 11.5, color: muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: muted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    final dangerSoft = isDark ? AppColors.dangerSoftDark : AppColors.dangerSoftLight;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          context.read<AuthProvider>().logout();
          Navigator.pushReplacementNamed(context, '/login');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: dangerSoft,
          foregroundColor: AppColors.danger,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 18),
            const SizedBox(width: 8),
            Text(
              'Sair da conta',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarDialog(BuildContext context, String? currentAvatar, String initial, bool isDark, Color accent) {
    final auth = context.read<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final avatarUrl = _avatarUrl(currentAvatar);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: AppColors.topFade(isDark),
                  ),
                ),
                child: Row(
                  children: [
                    _iconBtn(Icons.close, () => Navigator.pop(ctx), 38,
                        color: AppColors.onImage(isDark)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Mudar a foto do perfil',
                        style: GoogleFonts.poppins(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onImage(isDark),
                          shadows: isDark
                              ? [const Shadow(blurRadius: 3, color: Colors.black45)]
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (avatarUrl != null)
                      _iconBtn(
                        Icons.delete_outline,
                        () {
                          Navigator.pop(ctx);
                          _showConfirmDeleteDialog(context, auth);
                        },
                        38,
                        color: const Color(0xFFFF5C5C),
                      ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    // Avatar preview
                    Container(
                      width: 148,
                      height: 148,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [accent, accent.withValues(alpha: 0.7)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: avatarUrl != null
                          ? ClipOval(
                              child: Image.network(avatarUrl, fit: BoxFit.cover, width: 148, height: 148),
                            )
                          : Center(
                              child: Text(
                                initial,
                                style: GoogleFonts.poppins(fontSize: 64, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: _avatarActionBtn(
                            Icons.camera_alt,
                            'Câmera',
                            accent,
                            border,
                            () {
                              Navigator.pop(ctx);
                              _pickAndCrop(context, ImageSource.camera);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _avatarActionBtn(
                            Icons.photo_library,
                            'Galeria',
                            accent,
                            border,
                            () {
                              Navigator.pop(ctx);
                              _pickAndCrop(context, ImageSource.gallery);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancelar', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600, color: text)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Foto salva!', style: GoogleFonts.poppins()),
                            backgroundColor: text,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Salvar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirmDeleteDialog(BuildContext context, AuthProvider auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final surface = isDark ? AppColors.darkSurface : Colors.white;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.dangerSoftLight,
                  ),
                  child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 26),
                ),
                const SizedBox(height: 14),
                Text(
                  'Remover foto do perfil?',
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: text),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sua foto voltará ao padrão NutrIA. Essa ação não pode ser desfeita.',
                  style: GoogleFonts.poppins(fontSize: 13.5, color: muted, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Cancelar', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600, color: text)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          auth.removeAvatar();
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Remover', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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

  Widget _iconBtn(IconData icon, VoidCallback onTap, double size, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Icon(icon, size: 22, color: color ?? Colors.white),
      ),
    );
  }

  Widget _avatarActionBtn(IconData icon, String label, Color accent, Color border, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          border: Border.all(color: border, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: accent),
            const SizedBox(height: 7),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndCrop(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
    if (picked == null) return;

    final cropper = ImageCropper();
    final cropped = await cropper.cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          aspectRatioPresets: [CropAspectRatioPreset.square],
        ),
        IOSUiSettings(
          title: 'Recortar',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPresets: [CropAspectRatioPreset.square],
        ),
      ],
    );
    if (cropped == null) return;

    final bytes = await File(cropped.path).readAsBytes();
    final base64Str = base64Encode(bytes);
    final ext = cropped.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final dataUrl = 'data:$mime;base64,$base64Str';

    if (context.mounted) {
      context.read<AuthProvider>().updateAvatar(dataUrl);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto salva!', style: GoogleFonts.poppins()),
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
        );
      }
    }
  }
}
