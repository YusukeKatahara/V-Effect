import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_effect/l10n/app_localizations.dart';

import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../models/badge_definition.dart';
import '../services/user_service.dart';
import '../providers/service_providers.dart';
import '../widgets/premium_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/section_title.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/swipe_back_gate.dart';


class EditProfileScreen extends ConsumerStatefulWidget {
  final AppUser user;
  final Map<String, dynamic> privateData;

  const EditProfileScreen({
    super.key,
    required this.user,
    required this.privateData,
  });

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameCtrl;
  late TextEditingController _userIdCtrl;
  late TextEditingController _instagramIdCtrl;
  late final UserService _userService;

  bool _isSaving = false;
  XFile? _newProfileImage;
  Uint8List? _newProfileImageBytes; // Web でも表示できるようプレビューは bytes で保持
  String? _currentPhotoUrl;
  String? _equippedBadgeUrl;
  String? _equippedBadgeAnimation;
  String? _birthDate;
  String? _gender;
  List<String> _genderOptions(BuildContext ctx) {
    final l = AppLocalizations.of(ctx)!;
    return [l.editProfileGenderMale, l.editProfileGenderFemale, l.editProfileGenderOther];
  }

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
    _userService = ref.read(userServiceProvider);
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _userIdCtrl = TextEditingController(text: widget.user.userId);
    _instagramIdCtrl = TextEditingController(text: widget.user.instagramId ?? '');
    _currentPhotoUrl = widget.user.photoUrl;
    _equippedBadgeUrl = widget.user.equippedBadgeUrl;
    _equippedBadgeAnimation = widget.user.equippedBadgeAnimation;
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
    _instagramIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // 非同期処理を跨いで BuildContext（画面情報）を使用する警告（use_build_context_synchronously）を回避するため、
    // 最初の非同期処理が始まる前に多言語化テキストを取得（保存）しておきます。
    final l10n = AppLocalizations.of(context)!;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      // Web では image_cropper の UI が使えないため、選択画像をそのまま利用する
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        if (!mounted) return;
        setState(() {
          _newProfileImage = pickedFile;
          _newProfileImageBytes = bytes;
        });
        return;
      }
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: l10n.editProfileImageAdjust,
            toolbarColor: AppColors.bgSurface,
            toolbarWidgetColor: AppColors.textPrimary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: true,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: l10n.editProfileImageAdjust,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (croppedFile != null) {
        final bytes = await croppedFile.readAsBytes();
        if (!mounted) return;
        setState(() {
          _newProfileImage = XFile(croppedFile.path);
          _newProfileImageBytes = bytes;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final newUserId = _userIdCtrl.text.trim();
    final newUsername = _usernameCtrl.text.trim();
    final newInstagramId = _instagramIdCtrl.text.trim();


    bool isRestrictedFieldsChanged = false;

    // ユーザーIDの変更チェック（90日制限の対象）
    if (newUserId != widget.user.userId) {
      isRestrictedFieldsChanged = true;
    }

    if (isRestrictedFieldsChanged && _isRestricted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.editProfileChangeRestriction(_daysRemaining))),
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
                borderRadius: BorderRadius.circular(14),
              ),
              title: Text(
                AppLocalizations.of(context)!.editProfileConfirmTitle,
                style: TextStyle(color: AppColors.textPrimary),
              ),
              content: Text(
                AppLocalizations.of(context)!.editProfileConfirmMessage,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    AppLocalizations.of(context)!.editProfileCancel,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                  ),
                  child: Text(AppLocalizations.of(context)!.editProfileChange),
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
            ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.editProfileUserIdAlreadyUsed)));
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
        birthDate: _birthDate,
        gender: _gender,
        updateEditDate: isRestrictedFieldsChanged,
        equippedBadgeUrl: _equippedBadgeUrl,
        equippedBadgeAnimation: _equippedBadgeAnimation,
        instagramId: newInstagramId,
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
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.editProfileSaveFailed(e))));
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
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        AppLocalizations.of(context)!.editProfileSettingsHeader,
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
                  child: Form(
                    key: _formKey,
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              if (_isRestricted) _buildRestrictionWarning(),

                              // Photo upload
                              _buildPhotoPicker(),

                              const SizedBox(height: 32),

                              // Section: Account
                              SectionTitle(title: AppLocalizations.of(context)!.editProfileAccount),
                              const SizedBox(height: 12),
                              _buildTextField(_usernameCtrl, AppLocalizations.of(context)!.editProfileNameLabel, Icons.badge),
                              const SizedBox(height: 16),
                              _buildUserIdField(),
                              _buildPersonalInfoFields(),
                              const SizedBox(height: 16),
                              _buildInstagramIdField(),
                              const SizedBox(height: 32),

                              // Section: Preferences
                              SectionTitle(title: AppLocalizations.of(context)!.editProfileStatus),
                              const SizedBox(height: 12),

                              _buildBadgeRow(),
                              const SizedBox(height: 24),
                            ]),
                          ),
                        ),
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Save button
                                GradientButton(
                                  onPressed: _saveProfile,
                                  isLoading: _isSaving,
                                  child: Text(AppLocalizations.of(context)!.editProfileSave),
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
                        child: Text(AppLocalizations.of(context)!.editProfilePickerCancel, style: TextStyle(color: AppColors.textSecondary)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(AppLocalizations.of(context)!.editProfileBirthDatePickerTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton(
                        child: Text(AppLocalizations.of(context)!.editProfilePickerDone, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
                    data: CupertinoThemeData(
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
    final genderOpts = _genderOptions(context);
    int selectedIndex = genderOpts.indexOf(_gender ?? genderOpts[0]);
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
                      child: Text(AppLocalizations.of(context)!.editProfilePickerCancel, style: TextStyle(color: AppColors.textSecondary)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(AppLocalizations.of(context)!.editProfileGenderPickerTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      child: Text(AppLocalizations.of(context)!.editProfilePickerDone, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          _gender = genderOpts[selectedIndex];
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
                  data: CupertinoThemeData(
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
                    children: genderOpts.map((String value) {
                      return Center(
                        child: Text(
                          value,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 20),
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
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.cake_outlined, color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    Text(
                      _birthDate ?? AppLocalizations.of(context)!.editProfileBirthDate,
                      style: TextStyle(
                        color: _birthDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _showGenderPickerBottomSheet,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    Text(
                      _gender ?? AppLocalizations.of(context)!.editProfileGender,
                      style: TextStyle(
                        color: _gender == null ? AppColors.textSecondary : AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
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
          Icon(Icons.info_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.editProfileRestrictionMessage(_daysRemaining),
              style: TextStyle(color: AppColors.error, fontSize: 13),
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
                    _newProfileImageBytes != null
                        ? MemoryImage(_newProfileImageBytes!) as ImageProvider
                        : (_currentPhotoUrl != null
                            ? ResizeImage(
                              CachedNetworkImageProvider(_currentPhotoUrl!),
                              width: 300,
                            )
                            : null),
                child:
                    (_newProfileImage == null && _currentPhotoUrl == null)
                        ? Icon(
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
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
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
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textMuted),
      ),
      validator:
          (v) => (v == null || v.trim().isEmpty) ? AppLocalizations.of(context)!.editProfileNameRequired : null,
    );
  }

  Widget _buildUserIdField() {
    return TextFormField(
      controller: _userIdCtrl,
      enabled: !_isRestricted,
      style: TextStyle(
        color: _isRestricted ? AppColors.textMuted : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.editProfileUserIdLabel,
        prefixIcon: Icon(Icons.alternate_email, color: AppColors.textMuted),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.editProfileUserIdRequired;
        if (!_isAdmin) {
          if (v.trim().length < 5) return AppLocalizations.of(context)!.editProfileUserIdMinLength;
          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
            return AppLocalizations.of(context)!.editProfileUserIdAlphanumeric;
          }
        }
        return null;
      },
    );
  }

  Widget _buildInstagramIdField() {
    return TextFormField(
      controller: _instagramIdCtrl,
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'Instagram ID',
        prefixIcon: Icon(FontAwesomeIcons.instagram, color: AppColors.textMuted, size: 20),
      ),
      validator: (v) {
        if (v != null && v.trim().isNotEmpty) {
          if (!RegExp(r'^[a-zA-Z0-9_\.]+$').hasMatch(v.trim())) {
            return AppLocalizations.of(context)!.editProfileInstagramIdAlphanumeric;
          }
        }
        return null;
      },
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
            Icon(Icons.stars_rounded, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.editProfileBadgeLabel,
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
                      Text(
                        'T',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    else
                      Icon(Icons.verified, color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(context)!.editProfileBadgeEquipped,
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
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  AppLocalizations.of(context)!.editProfileBadgeNone,
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
              child: Text(
                AppLocalizations.of(context)!.editProfileBadgeChange,
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
    final List<Map<String, dynamic>> badgeOptions = [
      {
        'id': '',
        'label': AppLocalizations.of(context)!.editProfileBadgeOptionNone,
        'animation': 'none',
        'isOwned': true,
      },
    ];

    for (final def in BadgeDefinition.allBadges) {
      final bool isOwned = def.id == 'tester' || widget.user.ownedBadges.contains(def.id);
      badgeOptions.add({
        'id': def.id,
        'label': def.id == 'assets/icon/gratitude_heart_badge.png' ? '感謝' : def.name,
        'animation': def.animation,
        'isOwned': isOwned,
      });
    }

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
                Text(
                  AppLocalizations.of(context)!.editProfileBadgeSelectTitle,
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
                      children: badgeOptions.map((opt) {
                        return _buildBadgeOption(
                          opt['label'] as String,
                          opt['id'] as String,
                          opt['animation'] as String,
                          opt['isOwned'] as bool,
                        );
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

  Widget _buildBadgeOption(String label, String badgeUrl, String animation, bool isOwned) {
    final isSelected = (_equippedBadgeUrl ?? '') == badgeUrl;
    return GestureDetector(
      onTap: isOwned
          ? () {
              setState(() {
                _equippedBadgeUrl = badgeUrl;
                _equippedBadgeAnimation = animation;
              });
              Navigator.pop(context);
            }
          : null,
      child: Stack(
        children: [
          Opacity(
            opacity: isOwned ? 1.0 : 0.4,
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
                      child: badgeUrl.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: badgeUrl,
                              fit: BoxFit.contain,
                              errorWidget: (c, u, e) => Icon(Icons.broken_image, color: AppColors.textMuted),
                            )
                          : Image.asset(
                              badgeUrl == 'assets/icon/gratitude_heart_badge.png'
                                  ? 'assets/icon/gratitude_heart_badge_v3.png'
                                  : badgeUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: AppColors.textMuted),
                            ),
                    )
                  else
                    Icon(
                      Icons.do_disturb_alt_rounded,
                      color: AppColors.textMuted,
                      size: 40,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : (isOwned ? AppColors.textPrimary : AppColors.textMuted),
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
          ),
          if (!isOwned)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 12,
                  color: AppColors.accentGold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
