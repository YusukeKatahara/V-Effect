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
  final void Function(String trigger, String reward) onTaskUpdated;

  const SeasonHintModal({
    super.key,
    required this.task,
    required this.season,
    required this.onTaskUpdated,
  });

  static Future<void> show(
      BuildContext context, AppTask task, Season season, void Function(String trigger, String reward) onTaskUpdated) async {
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
  late TextEditingController _rewardController;

  @override
  void initState() {
    super.initState();
    _triggerController = TextEditingController(text: widget.task.trigger ?? '');
    _rewardController = TextEditingController(text: widget.task.reward ?? '');
  }

  @override
  void dispose() {
    _triggerController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  void _saveTask() {
    widget.onTaskUpdated(_triggerController.text.trim(), _rewardController.text.trim());
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
              const SizedBox(height: 32),
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
            
            // ご褒美設定フォーム
            Text(
              'あなたへのご褒美（完了時）', // TODO: 多言語対応が必要な場合は arb に追加
              style: GoogleFonts.notoSansJp(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.grey50,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rewardController,
              style: TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                hintText: '例: 好きな動画を見る、コーヒーを飲む',
                hintStyle: TextStyle(color: AppColors.grey70),
                filled: true,
                fillColor: AppColors.black.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),

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
