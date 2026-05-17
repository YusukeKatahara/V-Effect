import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';
import '../widgets/premium_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/section_title.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/swipe_back_gate.dart';
import '../services/push_notification_service.dart';

class EditProfileScreen extends StatefulWidget {
  final AppUser user;
  final Map<String, dynamic> privateData;

  const EditProfileScreen({
    super.key,
    required this.user,
    required this.privateData,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameCtrl;
  late TextEditingController _userIdCtrl;
  final _userService = UserService.instance;

  bool _isSaving = false;
  File? _newProfileImage;
  String? _currentPhotoUrl;


  bool _showTimestamp = true;

  bool _isRestricted = false;
  int _daysRemaining = 0;

  bool get _isAdmin {
    const adminEmails = [
      'ren0930ren0930@gmail.com', 
      'yusuke@example.com',
      'yusukekatahara@gmail.com',
      'y.katahara.academia@gmail.com'
    ];
    final email = widget.user.email ?? widget.privateData['email'] as String?;
    return email != null && adminEmails.contains(email);
  }

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _userIdCtrl = TextEditingController(text: widget.user.userId);
    _currentPhotoUrl = widget.user.photoUrl;


    _showTimestamp = widget.privateData['showTimestamp'] ?? true;

    _checkRestriction();
  }

  void _checkRestriction() {
    if (_isAdmin) {
      debugPrint('Admin/Test account: ID change restriction skipped.');
      _isRestricted = false;
      return;
    }

    if (widget.user.lastProfileEditDate != null) {
      final lastEdit = DateTime.fromMillisecondsSinceEpoch(
        widget.user.lastProfileEditDate!,
      );
      final now = DateTime.now();
      final diff = now.difference(lastEdit).inDays;
      if (diff < 90) {
        _isRestricted = true;
        _daysRemaining = 90 - diff;
      }
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '画像を調整',
            toolbarColor: AppColors.bgSurface,
            toolbarWidgetColor: AppColors.textPrimary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: true,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: '画像を調整',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _newProfileImage = File(croppedFile.path);
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final newUserId = _userIdCtrl.text.trim();
    final newUsername = _usernameCtrl.text.trim();


    bool isRestrictedFieldsChanged = false;

    // ユーザーIDの変更チェック（90日制限の対象）
    if (newUserId != widget.user.userId) {
      isRestrictedFieldsChanged = true;
    }

    if (isRestrictedFieldsChanged && _isRestricted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ユーザーIDの変更はあと $_daysRemaining 日経過するまでできません。')),
      );
      return;
    }

    if (isRestrictedFieldsChanged) {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: AppColors.bgElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                '確認',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              content: const Text(
                'この変更を保存すると、ユーザーIDは今後90日間変更できなくなります。\n\n本当によろしいですか？',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'キャンセル',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                  ),
                  child: const Text('変更'),
                ),
              ],
            ),
      );
      if (confirm != true) return;
    }

    setState(() => _isSaving = true);
    try {
      // ユーザーID変更チェック
      if (newUserId != widget.user.userId) {
        final available = await _userService.isUserIdAvailable(newUserId);
        if (!available) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('このユーザーIDは既に使われています')));
            setState(() => _isSaving = false);
          }
          return;
        }
      }

      String? updatedPhotoUrl = _currentPhotoUrl;
      // 画像アップロード
      if (_newProfileImage != null) {
        updatedPhotoUrl = await _userService.uploadProfileImage(
          _newProfileImage!,
        );
      }

      await _userService.updateProfile(
        username: newUsername,
        userId: newUserId,
        photoUrl: updatedPhotoUrl,
        showTimestamp: _showTimestamp,
        updateEditDate: isRestrictedFieldsChanged,
      );

      if (mounted) {
        // 保存中にユーザーが手動で戻った場合に二重 pop（ブラックアウト）するのを防ぐ
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop(true);
        }
      }
    } catch (e) {
      debugPrint('SaveProfile error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    return SwipeBackGate(
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          PremiumBackground(),
          SafeArea(
            child: Column(
              children: [
                // Custom header row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        '設定',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isRestricted) _buildRestrictionWarning(),

                          // Photo upload
                          _buildPhotoPicker(),

                          const SizedBox(height: 32),

                          // Section: Account
                          const SectionTitle(title: 'アカウント'),
                          const SizedBox(height: 12),
                          _buildTextField(_usernameCtrl, '名前', Icons.badge),
                          const SizedBox(height: 16),
                          _buildUserIdField(),
                          const SizedBox(height: 32),

                          // Section: Preferences
                          const SectionTitle(title: 'アプリ設定'),
                          const SizedBox(height: 12),

                          _buildTimestampToggle(),
                          const SizedBox(height: 32),

                          // Save button
                          GradientButton(
                            onPressed: _saveProfile,
                            isLoading: _isSaving,
                            child: const Text('保存'),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildRestrictionWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'ユーザーIDは前回の変更から90日間変更できません。\nあと $_daysRemaining 日お待ちください。',
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.5),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.white.withValues(alpha: 0.12),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.bgElevated,
                backgroundImage:
                    _newProfileImage != null
                        ? FileImage(_newProfileImage!) as ImageProvider
                        : (_currentPhotoUrl != null
                            ? ResizeImage(
                              CachedNetworkImageProvider(_currentPhotoUrl!),
                              width: 300,
                            )
                            : null),
                child:
                    (_newProfileImage == null && _currentPhotoUrl == null)
                        ? const Icon(
                          Icons.person,
                          size: 50,
                          color: AppColors.textMuted,
                        )
                        : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: AppColors.black,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textMuted),
      ),
      validator:
          (v) => (v == null || v.trim().isEmpty) ? '$labelを入力してください' : null,
    );
  }

  Widget _buildUserIdField() {
    return TextFormField(
      controller: _userIdCtrl,
      enabled: !_isRestricted,
      style: TextStyle(
        color: _isRestricted ? AppColors.textMuted : AppColors.textPrimary,
      ),
      decoration: const InputDecoration(
        labelText: 'ユーザーID',
        prefixIcon: Icon(Icons.alternate_email, color: AppColors.textMuted),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'ユーザーIDを入力してください';
        if (!_isAdmin) {
          if (v.trim().length < 5) return '5文字以上で入力してください';
          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
            return '英数字とアンダースコアのみ使えます';
          }
        }
        return null;
      },
    );
  }


  Widget _buildTimestampToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.textMuted),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '写真のタイムスタンプ',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '投稿写真に時刻を表示します',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _showTimestamp,
            onChanged: (v) => setState(() => _showTimestamp = v),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
