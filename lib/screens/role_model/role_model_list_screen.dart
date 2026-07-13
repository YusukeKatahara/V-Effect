import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../models/role_model.dart';
import '../../models/app_user.dart';
import '../../widgets/streak_flame.dart';
import '../../providers/role_model_provider.dart';
import '../../providers/service_providers.dart';
import '../../widgets/swipe_back_gate.dart';

/// ロールモデルの一覧を表示する画面
class RoleModelListScreen extends ConsumerWidget {
  const RoleModelListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleModelsAsync = ref.watch(roleModelsProvider);

    return SwipeBackGate(
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
          backgroundColor: AppColors.bgBase,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'ロールモデル一覧',
            style: GoogleFonts.notoSansJp(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: roleModelsAsync.when(
          data: (roleModels) {
            if (roleModels.isEmpty) {
              return Center(
                child: Text(
                  'ロールモデルが登録されていません',
                  style: GoogleFonts.notoSansJp(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              );
            }
            return ListView.builder(
              itemCount: roleModels.length,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemBuilder: (context, index) {
                final roleModel = roleModels[index];
                return _buildRoleModelTile(context, ref, roleModel);
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          error: (error, stack) => Center(
            child: Text(
              'データの取得に失敗しました',
              style: GoogleFonts.notoSansJp(
                color: AppColors.error,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleModelTile(BuildContext context, WidgetRef ref, RoleModel roleModel) {
    return FutureBuilder<AppUser?>(
      future: ref.read(friendServiceProvider).getUserByUid(roleModel.targetUid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final streak = user?.streak ?? 0;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.0),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.roleModelActivity,
                arguments: roleModel.targetUid,
              );
            },
            leading: _buildAvatar(roleModel),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    roleModel.displayName,
                    style: GoogleFonts.notoSansJp(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (streak > 0) ...[
                  const SizedBox(width: 8),
                  StreakFlame(size: 14, color: AppColors.accentGold),
                  const SizedBox(width: 4),
                  Text(
                    '$streak',
                    style: GoogleFonts.notoSansJp(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              '@${roleModel.username}',
              style: GoogleFonts.notoSansJp(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: OutlinedButton(
              onPressed: () => _removeRoleModel(context, ref, roleModel),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: Text(
                '解除',
                style: GoogleFonts.notoSansJp(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(RoleModel roleModel) {
    final photoUrl = roleModel.photoUrl;
    if (photoUrl == null || photoUrl.isEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.bgElevated,
        child: Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 24),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: photoUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppColors.bgElevated,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.bgElevated,
          child: Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 24),
        ),
      ),
    );
  }

  Future<void> _removeRoleModel(BuildContext context, WidgetRef ref, RoleModel roleModel) async {
    try {
      await ref.read(roleModelServiceProvider).removeRoleModel(roleModel.targetUid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${roleModel.displayName}さんのロールモデル登録を解除しました'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('解除に失敗しました: $e'),
          ),
        );
      }
    }
  }
}
