import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../services/analytics_service.dart';
import '../services/user_service.dart';
import '../widgets/premium_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/premium_icon_header.dart';
import '../widgets/section_title.dart';

/// 新規登録後のプロフィール設定画面（Step 1/2）
/// ユーザー名、ユーザーID、生年月日、性別を入力します
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  final _userService = UserService.instance;
  bool _isSaving = false;

  String? _occupation;

  List<String> _occupationOptions(BuildContext ctx) {
    final l = AppLocalizations.of(ctx)!;
    return [
      l.occupationEmployee, l.occupationExecutive, l.occupationCivilServant,
      l.occupationSelfEmployed, l.occupationProfessional, l.occupationEducation,
      l.occupationStudent, l.occupationPartTime, l.occupationHomemaker,
      l.occupationUnemployed, l.occupationOther,
    ];
  }

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _userIdCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _showOccupationPickerBottomSheet(BuildContext context) {
    final occupationOpts = _occupationOptions(context);
    int selectedIndex = occupationOpts.indexOf(_occupation ?? occupationOpts[0]);
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
                      child: Text(AppLocalizations.of(context)!.profileSetupPickerCancel, style: TextStyle(color: AppColors.textSecondary)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(AppLocalizations.of(context)!.profileSetupOccupationPickerTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      child: Text(AppLocalizations.of(context)!.profileSetupPickerDone, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          _occupation = occupationOpts[selectedIndex];
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
                    children: occupationOpts.map((String value) {
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

  Future<void> _saveAndNext() async {
    if (!_formKey.currentState!.validate()) return;

    // 追加項目のバリデーション
    if (_occupation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.profileSetupOccupationRequired)),
      );
      return;
    }


    setState(() => _isSaving = true);
    try {
      // ユーザーIDの重複チェック
      final available = await _userService.isUserIdAvailable(
        _userIdCtrl.text.trim(),
      );
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.profileSetupUserIdAlreadyUsed)));
        }
        return;
      }

      await _userService.saveProfile(
        username: _usernameCtrl.text.trim(),
        userId: _userIdCtrl.text.trim(),
        occupation: _occupation!,
      );

      await AnalyticsService.instance.logProfileSetupComplete();

      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.taskTemplate, (r) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.profileSetupSaveFailed)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // ── カスタムAppBar ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        if (Navigator.of(context).canPop())
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        Text(
                          AppLocalizations.of(context)!.profileSetupTitle,
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
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                const SizedBox(height: 8),
                                const PremiumIconHeader(
                                  icon: Icons.person_outline,
                                  size: 72,
                                  iconSize: 40,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Step 1 / 2',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)!.profileSetupSubtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // ユーザー名
                                TextFormField(
                                  controller: _usernameCtrl,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.of(context)!.profileSetupUsernameLabel,
                                    hintText: AppLocalizations.of(context)!.hintNameExample,
                                    prefixIcon: const Icon(Icons.badge),
                                  ),
                                  validator:
                                      (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? AppLocalizations.of(context)!.profileSetupUsernameRequired
                                              : null,
                                ),
                                const SizedBox(height: 16),

                                // ユーザーID
                                TextFormField(
                                  controller: _userIdCtrl,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.of(context)!.profileSetupUserIdLabel,
                                    hintText: AppLocalizations.of(context)!.onboardingProfileExampleIdHint,
                                    prefixIcon: const Icon(Icons.alternate_email),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return AppLocalizations.of(context)!.profileSetupUserIdRequired;
                                    }
                                    final adminEmails = [
                                      'ren0930ren0930@gmail.com',
                                      'yusuke@example.com',
                                      'yusukekatahara@gmail.com',
                                      'y.katahara.academia@gmail.com'
                                    ];
                                    final isSpecialAdmin = adminEmails.contains(FirebaseAuth.instance.currentUser?.email);
                                    if (!isSpecialAdmin) {
                                      if (v.trim().length < 5) {
                                        return AppLocalizations.of(context)!.profileSetupUserIdMinLength;
                                      }
                                      if (!RegExp(
                                        r'^[a-zA-Z0-9_]+$',
                                      ).hasMatch(v.trim())) {
                                        return AppLocalizations.of(context)!.profileSetupUserIdAlphanumeric;
                                      }
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),

                                // 職業
                                SectionTitle(title: AppLocalizations.of(context)!.profileSetupOccupationSection),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => _showOccupationPickerBottomSheet(context),
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
                                        Text(
                                          _occupation ?? AppLocalizations.of(context)!.profileSetupSelectPlaceholder,
                                          style: TextStyle(
                                            color: _occupation == null ? AppColors.textSecondary : AppColors.textPrimary,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ]),
                            ),
                          ),
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 28, right: 28, bottom: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  GradientButton(
                                    onPressed: _saveAndNext,
                                    isLoading: _isSaving,
                                    child: Text(AppLocalizations.of(context)!.profileSetupNextButton),
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
          ),
        ],
      ),
    );
  }
}
