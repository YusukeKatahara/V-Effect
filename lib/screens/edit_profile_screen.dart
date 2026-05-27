import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';
import '../widgets/premium_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/section_title.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/swipe_back_gate.dart';


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
  String? _equippedBadgeUrl;
  String? _equippedBadgeAnimation;

  bool _showTimestamp = true;
  String? _birthDate;
  String? _gender;
  static const _genderOptions = ['男性', '女性', 'その他'];

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
    _equippedBadgeUrl = widget.user.equippedBadgeUrl;
    _equippedBadgeAnimation = widget.user.equippedBadgeAnimation;


    _showTimestamp = widget.privateData['showTimestamp'] ?? true;
    _birthDate = widget.privateData['birthDate'] as String?;
    _gender = widget.privateData['gender'] as String?;

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
        birthDate: _birthDate,
        gender: _gender,
        updateEditDate: isRestrictedFieldsChanged,
        equippedBadgeUrl: _equippedBadgeUrl,
        equippedBadgeAnimation: _equippedBadgeAnimation,
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
                          _buildPersonalInfoFields(),
                          const SizedBox(height: 32),

                          // Section: Preferences
                          const SectionTitle(title: 'ステータス'),
                          const SizedBox(height: 12),

                          _buildBadgeRow(),
                          const SizedBox(height: 16),

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

  void _showDatePickerBottomSheet() {
    DateTime initialDate = DateTime(2000, 1, 1);
    if (_birthDate != null && _birthDate!.isNotEmpty) {
      try {
        final parts = _birthDate!.split('-');
        if (parts.length == 3) {
          initialDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      } catch (_) {}
    }

    DateTime selectedDate = initialDate;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext builder) {
        return Container(
          height: 300,
          padding: const EdgeInsets.only(top: 6.0),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        child: const Text('キャンセル', style: TextStyle(color: AppColors.textSecondary)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Text('生年月日', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton(
                        child: const Text('完了', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          setState(() {
                            _birthDate = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      brightness: Brightness.dark,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 22),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: selectedDate,
                      minimumYear: 1900,
                      maximumYear: DateTime.now().year,
                      onDateTimeChanged: (DateTime newDateTime) {
                        selectedDate = newDateTime;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGenderPickerBottomSheet() {
    int selectedIndex = _genderOptions.indexOf(_gender ?? _genderOptions[0]);
    if (selectedIndex == -1) selectedIndex = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext builder) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: const Text('キャンセル', style: TextStyle(color: AppColors.textSecondary)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text('性別', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      child: const Text('完了', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          _gender = _genderOptions[selectedIndex];
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 216,
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      pickerTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 20),
                    ),
                  ),
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                    itemExtent: 40,
                    onSelectedItemChanged: (int index) {
                      selectedIndex = index;
                    },
                    children: _genderOptions.map((String value) {
                      return Center(
                        child: Text(
                          value,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 20),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonalInfoFields() {
    return Column(
      children: [
        const SizedBox(height: 16),
        InkWell(
          onTap: _showDatePickerBottomSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cake_outlined, color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    Text(
                      _birthDate ?? '生年月日 (任意)',
                      style: TextStyle(
                        color: _birthDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _showGenderPickerBottomSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    Text(
                      _gender ?? '性別 (任意)',
                      style: TextStyle(
                        color: _gender == null ? AppColors.textSecondary : AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
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

  Widget _buildBadgeRow() {
    return InkWell(
      onTap: _showBadgeSelector,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.stars_rounded, color: AppColors.textMuted),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'バッジ',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_equippedBadgeUrl != null && _equippedBadgeUrl!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_equippedBadgeUrl == 'tester')
                      const Text(
                        'T',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    else
                      const Icon(Icons.verified, color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    const Text(
                      '装着中',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Text(
                  '未設定',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.grey20,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '変更',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeSelector() {
    // Generate the list of owned badges, deduplicated
    final Set<String> badges = {'', 'tester'};
    badges.addAll(widget.user.ownedBadges);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'バッジを選択',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: badges.map((badgeUrl) {
                        String label = '';
                        if (badgeUrl == '') label = 'なし';
                        else if (badgeUrl == 'tester') label = 'テスター';
                        else label = 'シーズンバッジ';
                        
                        return _buildBadgeOption(label, badgeUrl);
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadgeOption(String label, String badgeUrl) {
    final isSelected = (_equippedBadgeUrl ?? '') == badgeUrl;
    return GestureDetector(
      onTap: () {
        setState(() {
          _equippedBadgeUrl = badgeUrl;
          if (badgeUrl == 'tester') {
            _equippedBadgeAnimation = 'shimmer';
          } else {
            _equippedBadgeAnimation = ''; // Custom animation is handled by Season docs, but for simplicity here we clear it
          }
        });
        Navigator.pop(context);
      },
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (badgeUrl == 'tester')
              Container(
                height: 40,
                alignment: Alignment.center,
                child: Transform(
                  transform: Matrix4.skewX(-0.15),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                    Text(
                      'T',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3.5
                          ..color = AppColors.black.withValues(alpha: 0.8),
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFFFFF2CC),
                          Color(0xFFFFD700),
                          Color(0xFFD4AF37),
                          Color(0xFFFFF2CC),
                        ],
                        stops: [0.0, 0.4, 0.8, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        'T',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              )
            else if (badgeUrl.isNotEmpty)
              Container(
                height: 40,
                width: 40,
                alignment: Alignment.center,
                child: CachedNetworkImage(
                  imageUrl: badgeUrl,
                  fit: BoxFit.contain,
                  errorWidget: (c,u,e) => const Icon(Icons.broken_image, color: AppColors.textMuted),
                ),
              )
            else
              const Icon(
                Icons.do_disturb_alt_rounded,
                color: AppColors.textMuted,
                size: 40,
              ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
