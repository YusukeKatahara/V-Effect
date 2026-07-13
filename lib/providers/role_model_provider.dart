import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/role_model.dart';
import 'service_providers.dart';

/// ログイン中ユーザーのロールモデル一覧をリアルタイムに購読（監視）する StreamProvider
final roleModelsProvider = StreamProvider<List<RoleModel>>((ref) {
  final roleModelService = ref.watch(roleModelServiceProvider);
  return roleModelService.getRoleModelsStream();
});
