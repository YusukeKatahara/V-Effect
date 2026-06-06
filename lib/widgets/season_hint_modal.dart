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
  final ValueChanged<String> onTriggerUpdated;

  const SeasonHintModal({
    super.key,
    required this.task,
    required this.season,
    required this.onTriggerUpdated,
  });

  static Future<void> show(
      BuildContext context, AppTask task, Season season, ValueChanged<String> onTriggerUpdated) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SeasonHintModal(
        task: task,
        season: season,
        onTriggerUpdated: onTriggerUpdated,
      ),
    );
  }

  @override
  State<SeasonHintModal> createState() => _SeasonHintModalState();
}

class _SeasonHintModalState extends State<SeasonHintModal> {
  late TextEditingController _triggerController;

  @override
  void initState() {
    super.initState();
    _triggerController = TextEditingController(text: widget.task.trigger ?? '');
  }

  @override
  void dispose() {
    _triggerController.dispose();
    super.dispose();
  }

  void _saveTrigger() {
    widget.onTriggerUpdated(_triggerController.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
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
                const Icon(Icons.lightbulb_outline, color: AppColors.accentGold, size: 28),
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
                color: AppColors.grey20,
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
                  side: const BorderSide(color: AppColors.accentGold),
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
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.seasonHintTriggerHint,
                hintStyle: const TextStyle(color: AppColors.grey70),
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
              onPressed: _saveTrigger,
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
