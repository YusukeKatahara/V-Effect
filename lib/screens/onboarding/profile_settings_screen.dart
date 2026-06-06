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
import '../../widgets/gradient_button.dart';

class OnboardingProfileSettingsScreen extends StatefulWidget {
  const OnboardingProfileSettingsScreen({super.key});

  @override
  State<OnboardingProfileSettingsScreen> createState() =>
      _OnboardingProfileSettingsScreenState();
}

class _OnboardingProfileSettingsScreenState
    extends State<OnboardingProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  final _userService = UserService.instance;
  final _picker = ImagePicker();

  File? _profileImage;
  bool _isSaving = false;
  bool _canProceed = false;

  @override
  void initState() {
    super.initState();
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
        Navigator.pushNamed(context, AppRoutes.onboardingFirstQuest);
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
                              ? const Icon(
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
                            decoration: const BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
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
                    prefixIcon: const Icon(
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
