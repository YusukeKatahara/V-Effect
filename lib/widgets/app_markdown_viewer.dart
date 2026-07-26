import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';

/// V EFFECTアプリ共通 マークダウン＆プレーンテキスト対応ビューア
class AppMarkdownViewer extends StatelessWidget {
  /// 表示する本文（マークダウン記法、またはプレーンテキスト）
  final String data;

  /// テキストの長押し選択を許可するかどうか
  final bool selectable;

  const AppMarkdownViewer({
    super.key,
    required this.data,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: selectable,
      onTapLink: (text, href, title) async {
        if (href != null) {
          final uri = Uri.tryParse(href);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      styleSheet: MarkdownStyleSheet(
        h1: GoogleFonts.notoSansJp(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.white,
          height: 1.4,
        ),
        h2: GoogleFonts.notoSansJp(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
          height: 1.4,
        ),
        h3: GoogleFonts.notoSansJp(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
          height: 1.4,
        ),
        p: GoogleFonts.notoSansJp(
          fontSize: 15,
          color: AppColors.grey85,
          height: 1.8,
        ),
        strong: GoogleFonts.notoSansJp(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
        em: GoogleFonts.notoSansJp(
          fontSize: 15,
          color: AppColors.grey85,
          fontStyle: FontStyle.italic,
        ),
        listBullet: GoogleFonts.notoSansJp(
          fontSize: 15,
          color: AppColors.grey85,
          height: 1.8,
        ),
        blockquote: GoogleFonts.notoSansJp(
          fontSize: 14,
          color: AppColors.grey70,
          height: 1.6,
        ),
        code: GoogleFonts.sourceCodePro(
          fontSize: 13,
          color: AppColors.white,
          backgroundColor: AppColors.grey15,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppColors.grey10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.grey20, width: 0.5),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          color: AppColors.grey10,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          border: Border(
            left: BorderSide(color: AppColors.grey50, width: 3),
          ),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.grey20, width: 0.5),
          ),
        ),
        tableBorder: TableBorder.all(
          color: AppColors.grey30,
          width: 0.5,
        ),
        tableHead: GoogleFonts.notoSansJp(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
        tableBody: GoogleFonts.notoSansJp(
          fontSize: 14,
          color: AppColors.grey85,
        ),
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        blockSpacing: 12,
        h1Padding: const EdgeInsets.only(top: 12, bottom: 6),
        h2Padding: const EdgeInsets.only(top: 16, bottom: 6),
        h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
        pPadding: const EdgeInsets.only(bottom: 6),
        blockquotePadding: const EdgeInsets.all(12),
        listIndent: 20,
      ),
    );
  }
}
