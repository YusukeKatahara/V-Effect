import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../models/app_task.dart';
import '../models/season.dart';
import '../config/routes.dart';

class SeasonHintModal extends StatefulWidget {
  final AppTask task;
  final Season season;
  final void Function(String trigger) onTaskUpdated;

  const SeasonHintModal({
    super.key,
    required this.task,
    required this.season,
    required this.onTaskUpdated,
  });

  static Future<void> show(
    BuildContext context,
    AppTask task,
    Season season,
    void Function(String trigger) onTaskUpdated,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SeasonHintModal(
        task: task,
        season: season,
        onTaskUpdated: onTaskUpdated,
      ),
    );
  }

  @override
  State<SeasonHintModal> createState() => _SeasonHintModalState();
}

class _SeasonHintModalState extends State<SeasonHintModal> {
  late TextEditingController _triggerController;

  // ── Winter Arc 5大規律 ──
  static const List<String> _winterArcDisciplines = [
    '🏋️ ワークアウト',
    '🌅 自己規律',
    '🥷 スマホ断ち',
    '📖 読書・学習',
    '💧 食事・水',
  ];

  static const Map<String, ({String title, String subtitle, List<String> disciplines})> _winterArcPresets = {
    'Type A: 肉体改造': (
      title: 'Type A: 肉体改造',
      subtitle: '筋トレ / 起床 / 食事・水',
      disciplines: ['🏋️ ワークアウト', '🌅 自己規律', '💧 食事・水'],
    ),
    'Type B: 知性集中': (
      title: 'Type B: 知性集中',
      subtitle: '起床 / スマホ断ち / 読書',
      disciplines: ['🌅 自己規律', '🥷 スマホ断ち', '📖 読書・学習'],
    ),
    'Type C: 生活リセット': (
      title: 'Type C: 生活リセット',
      subtitle: '起床 / デトックス / 食事',
      disciplines: ['🌅 自己規律', '🥷 スマホ断ち', '💧 食事・水'],
    ),
    'Type D: 自分で選ぶ': (
      title: 'Type D: 自分で選ぶ',
      subtitle: '5大規律から自由に3つ',
      disciplines: [],
    ),
  };

  final Set<String> _selectedDisciplines = {};
  String _selectedType = '';

  bool get _isWinterArc {
    final title = widget.task.title.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final sId = widget.season.id.toLowerCase();
    final sName = widget.season.taskName.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    return title.contains('WINTERARC') ||
        sId.contains('winter_arc') ||
        sName.contains('WINTERARC');
  }

  @override
  void initState() {
    super.initState();
    _triggerController = TextEditingController(text: widget.task.trigger ?? '');

    if (_isWinterArc) {
      _initWinterArcSelection();
    }
  }

  void _initWinterArcSelection() {
    final currentText = widget.task.trigger ?? '';
    for (final disc in _winterArcDisciplines) {
      final cleanKeyword = disc.replaceAll(RegExp(r'[^\u4e00-\u9fa5\u3040-\u309f\u30a0-\u30ff]'), '').trim();
      if (currentText.contains(disc) || (cleanKeyword.isNotEmpty && currentText.contains(cleanKeyword))) {
        _selectedDisciplines.add(disc);
      }
    }

    // プリセットと完全一致するかチェック
    for (final entry in _winterArcPresets.entries) {
      if (entry.key == 'Type D: 自分で選ぶ') continue;
      final presetDiscs = entry.value.disciplines;
      if (presetDiscs.length == _selectedDisciplines.length &&
          presetDiscs.every((d) => _selectedDisciplines.contains(d))) {
        _selectedType = entry.key;
        return;
      }
    }

    if (_selectedDisciplines.isNotEmpty) {
      _selectedType = 'Type D: 自分で選ぶ';
    } else {
      // 初期値は Type A
      _applyPreset('Type A: 肉体改造', _winterArcPresets['Type A: 肉体改造']!.disciplines);
    }
  }

  void _applyPreset(String typeKey, List<String> disciplines) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedType = typeKey;
      _selectedDisciplines.clear();
      _selectedDisciplines.addAll(disciplines);
      _triggerController.text = _selectedDisciplines.join(' / ');
    });
  }

  void _toggleDiscipline(String discipline) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedType = 'Type D: 自分で選ぶ';
      if (_selectedDisciplines.contains(discipline)) {
        _selectedDisciplines.remove(discipline);
      } else {
        if (_selectedDisciplines.length < 3) {
          _selectedDisciplines.add(discipline);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('選べる規律は最大3つまでです（無理のない継続のため）'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
      }
      _triggerController.text = _selectedDisciplines.join(' / ');
    });
  }

  @override
  void dispose() {
    _triggerController.dispose();
    super.dispose();
  }

  void _saveTask() {
    widget.onTaskUpdated(_triggerController.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = AppColors.isDark;

    final sheetBg = isDark ? const Color(0xFF141416) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);
    final cardBorder = isDark ? const Color(0xFF2C2C32) : const Color(0xFFE2E8F0);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: _isWinterArc
                ? AppColors.accentGold.withValues(alpha: 0.6)
                : (isDark ? const Color(0xFF2C2C32) : const Color(0xFFE2E8F0)),
            width: _isWinterArc ? 1.5 : 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── ドラッグハンドルバー ──
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3A3A42) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── ヘッダー部 ──
                  if (_isWinterArc) ...[
                    _buildWinterArcHeroBanner(isDark: isDark, textMain: textMain, textMuted: textMuted),
                    const SizedBox(height: 20),

                    // ── 規律スタイル選択（Type A〜D カード） ──
                    Row(
                      children: [
                        Icon(Icons.style_rounded, color: AppColors.accentGold, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '規律スタイルを選ぶ',
                          style: GoogleFonts.notoSansJp(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: textMain,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '3つの規律を選択',
                            style: GoogleFonts.notoSansJp(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    _buildPresetGrid(isDark: isDark, cardBg: cardBg, cardBorder: cardBorder, textMain: textMain, textMuted: textMuted),
                    const SizedBox(height: 20),

                    // ── 5大規律個別セレクター ──
                    Row(
                      children: [
                        Icon(Icons.checklist_rounded, color: AppColors.accentGold, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '5大規律（タップで入れ替え）',
                          style: GoogleFonts.notoSansJp(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: textMain,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedDisciplines.length}/3 選択中',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _selectedDisciplines.length == 3 ? AppColors.accentGold : textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    _buildDisciplinesChips(isDark: isDark, cardBg: cardBg, cardBorder: cardBorder, textMain: textMain),
                    const SizedBox(height: 18),

                    // ── 1秒写真証明術（Photo Proof）ティップス ──
                    _buildPhotoProofCard(isDark: isDark, textMain: textMain, textMuted: textMuted),
                    const SizedBox(height: 14),

                    // ── 公式解説ブログへの導線 ──
                    _buildBlogButton(),
                    const SizedBox(height: 22),
                  ] else ...[
                    // 通常シーズンタスク時の標準ヒント表示
                    _buildStandardHeader(textMain: textMain, textMuted: textMuted),
                    const SizedBox(height: 20),
                  ],

                  // ── あなたの規律（トリガー）設定欄 ──
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: AppColors.accentGold, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _isWinterArc ? 'あなたの3大規律（登録内容）' : AppLocalizations.of(context)!.seasonHintTriggerLabel,
                        style: GoogleFonts.notoSansJp(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: textMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder, width: 1),
                    ),
                    child: TextField(
                      controller: _triggerController,
                      style: GoogleFonts.notoSansJp(
                        color: textMain,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: _isWinterArc
                            ? '例: 🏋️ ワークアウト / 🌅 自己規律 / 💧 食事・水'
                            : AppLocalizations.of(context)!.seasonHintTriggerHint,
                        hintStyle: GoogleFonts.notoSansJp(color: textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── 決定・保存ボタン ──
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _saveTask();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFDF73),
                            Color(0xFFD4AF37),
                            Color(0xFFB88E18),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentGold.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _isWinterArc ? 'この3つの規律で挑む 🔥' : AppLocalizations.of(context)!.seasonHintSaveButton,
                            style: GoogleFonts.notoSansJp(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
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

  // ── Winter Arc ヒーローバナー ──
  Widget _buildWinterArcHeroBanner({
    required bool isDark,
    required Color textMain,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1C2234), const Color(0xFF131620)]
              : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
        ),
        border: Border.all(
          color: AppColors.accentGold.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGold.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icon/winter_arc_2026.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1A1A24),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.ac_unit_rounded,
                    color: AppColors.accentGold,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'WINTER ARC 2026',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.accentGold,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '0/40 達成',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentGold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '❄️ 冬の3ヶ月で覚醒する5大規律',
                  style: GoogleFonts.notoSansJp(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentGold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '他人が休んでいる間に自分を磨き抜く。\n迷ったらここから3つ選ぼう（3 Non-Negotiables）。',
                  style: GoogleFonts.notoSansJp(
                    fontSize: 11,
                    height: 1.35,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── プリセットグリッド（Type A〜D） ──
  Widget _buildPresetGrid({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textMain,
    required Color textMuted,
  }) {
    final entries = _winterArcPresets.entries.toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.1,
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = _selectedType == entry.key;

        return GestureDetector(
          onTap: () {
            if (entry.key == 'Type D: 自分で選ぶ') {
              setState(() {
                _selectedType = 'Type D: 自分で選ぶ';
              });
            } else {
              _applyPreset(entry.key, entry.value.disciplines);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentGold.withValues(alpha: isDark ? 0.2 : 0.12)
                  : cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.accentGold
                    : cardBorder,
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.accentGold.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.value.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansJp(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          color: isSelected ? AppColors.accentGold : textMain,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: AppColors.accentGold, size: 14),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  entry.value.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? (isDark ? Colors.white70 : const Color(0xFF334155)) : textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 5大規律チップス ──
  Widget _buildDisciplinesChips({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textMain,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _winterArcDisciplines.map((discipline) {
        final isSelected = _selectedDisciplines.contains(discipline);

        return GestureDetector(
          onTap: () => _toggleDiscipline(discipline),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentGold.withValues(alpha: isDark ? 0.25 : 0.15)
                  : cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accentGold : cardBorder,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(Icons.check_rounded, color: AppColors.accentGold, size: 15),
                  const SizedBox(width: 5),
                ],
                Text(
                  discipline,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.accentGold : textMain,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── 1秒写真証明術（Photo Proof）カード ──
  Widget _buildPhotoProofCard({
    required bool isDark,
    required Color textMain,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF1F5F9),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.camera_alt_rounded,
              color: AppColors.accentGold,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📷 1秒でOK！億劫にならない証明写真術',
                  style: GoogleFonts.notoSansJp(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '画面の明るさを下げて暗め撮影。ダンベル、コーヒーの湯気、閉じたPC、時計などをパシャリ！顔出し不要でカッコよく証明できます。',
                  style: GoogleFonts.notoSansJp(
                    fontSize: 10.5,
                    height: 1.4,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 公式攻略ガイドブログへの導線ボタン ──
  Widget _buildBlogButton() {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.of(context).pushNamed(
          AppRoutes.blogPostDetail,
          arguments: 'winter-arc-2026',
        );
      },
      icon: const Icon(Icons.menu_book_rounded, size: 16),
      label: Text(
        '📖 ウィンターアーク完全攻略ガイドを読む',
        style: GoogleFonts.notoSansJp(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentGold,
        side: BorderSide(
          color: AppColors.accentGold.withValues(alpha: 0.6),
          width: 1.2,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── 通常シーズンタスク時の標準ヘッダー ──
  Widget _buildStandardHeader({
    required Color textMain,
    required Color textMuted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline, color: AppColors.accentGold, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.season.hintTitle ?? AppLocalizations.of(context)!.seasonHintDefaultTitle,
                style: GoogleFonts.notoSansJp(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.season.hintBody ?? AppLocalizations.of(context)!.seasonHintDefaultBody,
          style: GoogleFonts.notoSansJp(
            fontSize: 13.5,
            color: textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
