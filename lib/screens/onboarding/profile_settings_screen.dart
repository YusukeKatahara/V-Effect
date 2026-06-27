import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../services/user_service.dart';
import '../../providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/gradient_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/app_user.dart';
import '../../widgets/notification_prompt_sheet.dart';
import '../../widgets/friend_invite_prompt_sheet.dart';

class OnboardingProfileSettingsScreen extends ConsumerStatefulWidget {
  const OnboardingProfileSettingsScreen({super.key});

  @override
  ConsumerState<OnboardingProfileSettingsScreen> createState() =>
      _OnboardingProfileSettingsScreenState();
}

class _OnboardingProfileSettingsScreenState
    extends ConsumerState<OnboardingProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  late final UserService _userService;
  final _picker = ImagePicker();

  File? _profileImage;
  bool _isSaving = false;
  bool _canProceed = false;

  @override
  void initState() {
    super.initState();
    _userService = ref.read(userServiceProvider);
    _usernameCtrl.addListener(_updateCanProceed);
    _userIdCtrl.addListener(_updateCanProceed);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  void _updateCanProceed() {
    final ok =
        _usernameCtrl.text.trim().isNotEmpty &&
        _userIdCtrl.text.trim().isNotEmpty;
    if (ok != _canProceed) setState(() => _canProceed = ok);
  }

  String? _validateUserId(String? v) {
    if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.onboardingProfileUserIdRequired;
    const adminEmails = [
      'ren0930ren0930@gmail.com',
      'yusuke@example.com',
      'yusukekatahara@gmail.com',
      'y.katahara.academia@gmail.com',
    ];
    final isAdmin = adminEmails
        .contains(FirebaseAuth.instance.currentUser?.email);
    if (!isAdmin) {
      if (v.trim().length < 5) return AppLocalizations.of(context)!.onboardingProfileUserIdMinLength;
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
        return AppLocalizations.of(context)!.onboardingProfileUserIdAlphanumeric;
      }
    }
    return null;
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked != null && !kIsWeb && mounted) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: AppLocalizations.of(context)!.onboardingProfileImageAdjust,
            toolbarColor: AppColors.bgSurface,
            toolbarWidgetColor: AppColors.textPrimary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: true,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: AppLocalizations.of(context)!.onboardingProfileImageAdjust,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        setState(() => _profileImage = File(croppedFile.path));
      }
    }
  }

  Future<void> _checkAndShowNotificationPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _userService.currentUid;
    if (uid == null) return;

    // すでに表示済みの場合は何もしません
    final hasShown = prefs.getBool('notification_prompt_shown_$uid') ?? false;
    if (hasShown) return;

    try {
      // すでに通知許可済みの場合はモーダルを表示する必要がないため、フラグだけ立ててスキップします
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await prefs.setBool('notification_prompt_shown_$uid', true);
        return;
      }

      if (mounted) {
        // ハーフモーダル (プレ・ダイアログ) を表示し、その中で自動でOS通知パーミッション要求をトリガーします
        await NotificationPromptSheet.show(context);
        
        // 次回以降表示されないようにフラグを保存します
        await prefs.setBool('notification_prompt_shown_$uid', true);
      }
    } catch (e) {
      debugPrint('通知プロンプト表示エラー: $e');
    }
  }

  Future<void> _checkAndShowFriendInvitePrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _userService.currentUid;
    if (uid == null) return;

    // すでに表示済みの場合は何もしません
    final hasShown = prefs.getBool('friend_invite_prompt_shown_$uid') ?? false;
    if (hasShown) return;

    try {
      // 最新のユーザー情報をFirestoreから取得します
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!snap.exists) return;
      final user = AppUser.fromFirestore(snap);

      if (mounted) {
        // ハーフモーダル (下からせり出るシート) を表示し、結果を受け取ります
        final result = await FriendInvitePromptSheet.show(context, user);

        // 次回以降表示されないようにフラグを保存します
        await prefs.setBool('friend_invite_prompt_shown_$uid', true);

        // 「QRコードで繋がる」が選択された場合、呼び出し元（この画面）のcontextでダイアログを表示
        if (result == FriendInviteResult.qrCode && mounted) {
          FriendInvitePromptSheet.showQrDialog(context, user);
        }
      }
    } catch (e) {
      debugPrint('フレンド招待プロンプト表示エラー: $e');
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final username = _usernameCtrl.text.trim();
    final userId = _userIdCtrl.text.trim();

    setState(() => _isSaving = true);
    try {
      final available = await _userService.isUserIdAvailable(userId);
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.onboardingProfileUserIdAlreadyUsed)),
          );
        }
        return;
      }

      String? photoUrl;
      if (_profileImage != null) {
        photoUrl = await _userService.uploadProfileImage(_profileImage!);
      }

      await _userService.saveOnboardingProfile(
        username: username,
        userId: userId,
        photoUrl: photoUrl,
      );

      if (mounted) {
        // オンボーディング完了後（ホーム画面へ遷移する前）に通知許可プロンプトを表示
        await _checkAndShowNotificationPrompt();
        
        // 通知許可の後にフレンド招待プロンプトを表示
        if (mounted) {
          await _checkAndShowFriendInvitePrompt();
        }

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (r) => false,
            arguments: 1, // HeroTasks タブ
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.onboardingProfileSaveFailed(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 64),
                Text(
                  AppLocalizations.of(context)!.onboardingProfileWelcome,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.onboardingProfileSubtitle,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 14,
                    color: AppColors.grey50,
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: AppColors.grey15,
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : null,
                          child: _profileImage == null
                              ? Icon(
                                  Icons.person,
                                  size: 52,
                                  color: AppColors.grey50,
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_a_photo,
                              size: 16,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _usernameCtrl,
                  style: GoogleFonts.notoSansJp(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.onboardingProfileUsernameLabel,
                    labelStyle: GoogleFonts.notoSansJp(
                      color: AppColors.grey50,
                    ),
                    hintText: AppLocalizations.of(context)!.onboardingProfileUsernameHint,
                    hintStyle: GoogleFonts.notoSansJp(
                      color: AppColors.grey30,
                      fontSize: 14,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? AppLocalizations.of(context)!.onboardingProfileUsernameRequired : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _userIdCtrl,
                  style: GoogleFonts.notoSansJp(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.onboardingProfileUserIdLabel,
                    labelStyle: GoogleFonts.notoSansJp(
                      color: AppColors.grey50,
                    ),
                    hintText: AppLocalizations.of(context)!.onboardingProfileExampleIdHint,
                    hintStyle: GoogleFonts.notoSansJp(
                      color: AppColors.grey30,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.alternate_email,
                      color: AppColors.grey50,
                    ),
                    helperText: AppLocalizations.of(context)!.onboardingProfileHelperText,
                    helperStyle: GoogleFonts.notoSansJp(
                      color: AppColors.grey30,
                      fontSize: 11,
                    ),
                  ),
                  validator: _validateUserId,
                ),
                const SizedBox(height: 56),
                GradientButton(
                  onPressed: _canProceed ? _save : null,
                  isLoading: _isSaving,
                  child: Text(
                    AppLocalizations.of(context)!.onboardingProfileStartButton,
                    style: GoogleFonts.notoSansJp(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
