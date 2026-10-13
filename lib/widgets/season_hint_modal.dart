import 'package:flutter/material.dart';
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
      BuildContext context, AppTask task, Season season, void Function(String trigger) onTaskUpdated) async {
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

  static const Map<String, List<String>> _winterArcPresets = {
    'Type A: 肉体改造': ['🏋️ ワークアウト', '🌅 自己規律', '💧 食事・水'],
    'Type B: 知性集中': ['🌅 自己規律', '🥷 スマホ断ち', '📖 読書・学習'],
    'Type C: 生活リセット': ['🌅 自己規律', '🥷 スマホ断ち', '💧 食事・水'],
  };

  final Set<String> _selectedDisciplines = {};
  String _selectedType = ''; // 'Type A: 肉体改造', 'Type B: 知性集中', 'Type C: 生活リセット', 'Type D: 自分で3つ選ぶ'

  bool get _isWinterArc {
    final title = widget.task.title.toUpperCase();
    final sId = widget.season.id.toLowerCase();
    final sName = widget.season.taskName.toUpperCase();
    return title.contains('WINTER ARC') ||
        sId.contains('winter_arc') ||
        sName.contains('WINTER ARC');
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
      // 絵文字を除いたキーワードでも部分一致判定
      final cleanKeyword = disc.replaceAll(RegExp(r'[^\u4e00-\u9fa5\u3040-\u309f\u30a0-\u30ff]'), '').trim();
      if (currentText.contains(disc) || (cleanKeyword.isNotEmpty && currentText.contains(cleanKeyword))) {
        _selectedDisciplines.add(disc);
      }
    }

    // プリセットと完全一致するかチェック
    for (final entry in _winterArcPresets.entries) {
      if (entry.value.length == _selectedDisciplines.length &&
          entry.value.every((d) => _selectedDisciplines.contains(d))) {
        _selectedType = entry.key;
        return;
      }
    }

    if (_selectedDisciplines.isNotEmpty) {
      _selectedType = 'Type D: 自分で3つ選ぶ';
    }
  }

  void _applyPreset(String typeKey, List<String> disciplines) {
    setState(() {
      _selectedType = typeKey;
      _selectedDisciplines.clear();
      _selectedDisciplines.addAll(disciplines);
      _triggerController.text = _selectedDisciplines.join(' / ');
    });
  }

  void _toggleDiscipline(String discipline) {
    setState(() {
      _selectedType = 'Type D: 自分で3つ選ぶ';
      if (_selectedDisciplines.contains(discipline)) {
        _selectedDisciplines.remove(discipline);
      } else {
        if (_selectedDisciplines.length < 3) {
          _selectedDisciplines.add(discipline);
        } else {
          // すでに3つ選択されている場合はトースト・ガイダンス
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
    
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヒントの表示
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.accentGold, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.season.hintTitle ?? AppLocalizations.of(context)!.seasonHintDefaultTitle,
                    style: GoogleFonts.notoSansJp(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.season.hintBody ?? AppLocalizations.of(context)!.seasonHintDefaultBody,
              style: GoogleFonts.notoSansJp(
                fontSize: 14,
                color: AppColors.grey85,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            
            // ブログ連携ボタン
            if (widget.season.relatedBlogId != null && widget.season.relatedBlogId!.isNotEmpty) ...[
              OutlinedButton.icon(
                onPressed: () {
                  // お知らせ（ブログ）詳細へ遷移
                  // NOTE: 引数の渡し方は既存のルーティングに従う
                  // ここではブログIDを渡すなどの実装が必要ですが、ひとまず遷移だけを記述
                  Navigator.of(context).pushNamed(AppRoutes.blogPostDetail, arguments: widget.season.relatedBlogId);
                },
                icon: const Icon(Icons.article_outlined, size: 20),
                label: Text(AppLocalizations.of(context)!.seasonHintReadBlog),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentGold,
                  side: BorderSide(color: AppColors.accentGold),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Winter Arc 専用: 規律スタイル選択 (Type A〜D) & 5大規律チップ ──
            if (_isWinterArc) ...[
              Row(
                children: [
                  Icon(Icons.checklist_rounded, color: AppColors.accentGold, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '規律スタイルを選ぶ（3つ選択）',
                    style: GoogleFonts.notoSansJp(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentGold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // プリセットボタン一覧
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._winterArcPresets.entries.map((entry) {
                    final isSelected = _selectedType == entry.key;
                    return ChoiceChip(
                      label: Text(entry.key),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _applyPreset(entry.key, entry.value);
                        }
                      },
                      selectedColor: AppColors.accentGold.withValues(alpha: 0.25),
                      backgroundColor: AppColors.black.withValues(alpha: 0.3),
                      labelStyle: GoogleFonts.notoSansJp(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.accentGold : AppColors.grey70,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.accentGold : AppColors.grey30,
                        width: 1,
                      ),
                    );
                  }),
                  ChoiceChip(
                    label: Text(
                      _selectedType == 'Type D: 自分で3つ選ぶ'
                          ? 'Type D: 自分で3つ選ぶ (${_selectedDisciplines.length}/3)'
                          : 'Type D: 自分で3つ選ぶ',
                    ),
                    selected: _selectedType == 'Type D: 自分で3つ選ぶ',
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = 'Type D: 自分で3つ選ぶ';
                      });
                    },
                    selectedColor: AppColors.accentGold.withValues(alpha: 0.25),
                    backgroundColor: AppColors.black.withValues(alpha: 0.3),
                    labelStyle: GoogleFonts.notoSansJp(
                      fontSize: 12,
                      fontWeight: _selectedType == 'Type D: 自分で3つ選ぶ' ? FontWeight.bold : FontWeight.normal,
                      color: _selectedType == 'Type D: 自分で3つ選ぶ' ? AppColors.accentGold : AppColors.grey70,
                    ),
                    side: BorderSide(
                      color: _selectedType == 'Type D: 自分で3つ選ぶ' ? AppColors.accentGold : AppColors.grey30,
                      width: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 5大規律の個別チップ
              Text(
                '5大規律からタップして選ぶ (最大3つ):',
                style: GoogleFonts.notoSansJp(
                  fontSize: 12,
                  color: AppColors.grey50,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _winterArcDisciplines.map((discipline) {
                  final isSelected = _selectedDisciplines.contains(discipline);
                  return FilterChip(
                    label: Text(discipline),
                    selected: isSelected,
                    onSelected: (_) => _toggleDiscipline(discipline),
                    selectedColor: AppColors.accentGold,
                    checkmarkColor: AppColors.black,
                    backgroundColor: AppColors.black.withValues(alpha: 0.3),
                    labelStyle: GoogleFonts.notoSansJp(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.black : AppColors.white,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppColors.accentGold : AppColors.grey30,
                      width: 1,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // トリガー設定フォーム
            Text(
              AppLocalizations.of(context)!.seasonHintTriggerLabel,
              style: GoogleFonts.notoSansJp(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.grey50,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _triggerController,
              style: TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.seasonHintTriggerHint,
                hintStyle: TextStyle(color: AppColors.grey70),
                filled: true,
                fillColor: AppColors.black.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            


            // 保存ボタン
            ElevatedButton(
              onPressed: _saveTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: AppColors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                AppLocalizations.of(context)!.seasonHintSaveButton,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
