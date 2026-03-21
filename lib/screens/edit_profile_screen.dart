import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';
import '../widgets/premium_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/section_title.dart';

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
  final List<TextEditingController> _taskCtrls = [];
  final _userService = UserService();

  bool _isSaving = false;
  File? _newProfileImage;
  String? _currentPhotoUrl;

  late int? _birthYear;
  late int? _birthMonth;
  late int? _birthDay;

  TimeOfDay? _wakeUpTime;
  TimeOfDay? _taskTime;

  bool _isRestricted = false;
  int _daysRemaining = 0;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _userIdCtrl = TextEditingController(text: widget.user.userId);
    _currentPhotoUrl = widget.user.photoUrl;

    if (widget.user.tasks.isEmpty) {
      _taskCtrls.add(TextEditingController());
    } else {
      for (final task in widget.user.tasks) {
        _taskCtrls.add(TextEditingController(text: task));
      }
    }

    // Parse BirthDate: YYYY-MM-DD
    final birthDateStr = widget.privateData['birthDate'] as String?;
    if (birthDateStr != null && birthDateStr.contains('-')) {
      final parts = birthDateStr.split('-');
      if (parts.length == 3) {
        _birthYear = int.tryParse(parts[0]);
        _birthMonth = int.tryParse(parts[1]);
        _birthDay = int.tryParse(parts[2]);
      } else {
        _birthYear = null; _birthMonth = null; _birthDay = null;
      }
    } else {
      _birthYear = null; _birthMonth = null; _birthDay = null;
    }

    _wakeUpTime = _parseTimeOfDay(widget.privateData['wakeUpTime'] as String?);
    _taskTime = _parseTimeOfDay(widget.privateData['taskTime'] as String?);

    _checkRestriction();
  }

  void _checkRestriction() {
    if (widget.user.lastProfileEditDate != null) {
      final lastEdit = DateTime.fromMillisecondsSinceEpoch(widget.user.lastProfileEditDate!);
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
    for (final ctrl in _taskCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _addTaskField() {
    if (_taskCtrls.length >= 5) return;
    setState(() => _taskCtrls.add(TextEditingController()));
  }

  void _removeTaskField(int index) {
    if (_taskCtrls.length <= 1) return;
    setState(() {
      _taskCtrls[index].dispose();
      _taskCtrls.removeAt(index);
    });
  }

  TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return null;
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  int _daysInMonth(int year, int month) {
    return DateUtils.getDaysInMonth(year, month);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _newProfileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickTime(bool isWakeUpTime) async {
    final initialTime = (isWakeUpTime ? _wakeUpTime : _taskTime) ?? const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isWakeUpTime) {
          _wakeUpTime = picked;
        } else {
          _taskTime = picked;
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // 生年月日のバリデーション
    if (_birthYear == null || _birthMonth == null || _birthDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生年月日をすべて選択してください')),
      );
      return;
    }

    if (_wakeUpTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('起床時間を選択してください')),
      );
      return;
    }

    if (_taskTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タスク実行時間を選択してください')),
      );
      return;
    }

    final newTasks = _taskCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (newTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タスクを1つ以上入力してください')),
      );
      return;
    }

    final newUserId = _userIdCtrl.text.trim();
    final newUsername = _usernameCtrl.text.trim();
    final birthDateStr = '${_birthYear!}-${_birthMonth!.toString().padLeft(2, '0')}-${_birthDay!.toString().padLeft(2, '0')}';
    final wakeUpTimeStr = _formatTimeOfDay(_wakeUpTime!);
    final taskTimeStr = _formatTimeOfDay(_taskTime!);

    bool isRestrictedFieldsChanged = false;

    if (newUserId != widget.user.userId ||
        _newProfileImage != null ||
        birthDateStr != widget.privateData['birthDate']) {
      isRestrictedFieldsChanged = true;
    }

    if (isRestrictedFieldsChanged && _isRestricted) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('名前以外の変更はあと $_daysRemaining 日経過するまでできません。')),
      );
      return;
    }

    if (isRestrictedFieldsChanged) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('確認', style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'この変更を保存すると、名前以外のプロフィール項目は今後90日間変更できなくなります。\n\n本当によろしいですか？',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.black,
              ),
              child: const Text('変更する'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isSaving = true);
    try {
      // ユーザーID変更チェック
      final newUserId = _userIdCtrl.text.trim();
      if (newUserId != widget.user.userId) {
        final available = await _userService.isUserIdAvailable(newUserId);
        if (!available) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('このユーザーIDは既に使われています')),
            );
            setState(() => _isSaving = false);
          }
          return;
        }
      }

      String? updatedPhotoUrl = _currentPhotoUrl;
      // 画像アップロード
      if (_newProfileImage != null) {
        updatedPhotoUrl = await _userService.uploadProfileImage(_newProfileImage!);
      }

      final birthDate = '${_birthYear!}-${_birthMonth!.toString().padLeft(2, '0')}-${_birthDay!.toString().padLeft(2, '0')}';

      await _userService.updateProfile(
        username: newUsername,
        userId: newUserId,
        photoUrl: updatedPhotoUrl,
        birthDate: birthDate,
        wakeUpTime: wakeUpTimeStr,
        taskTime: taskTimeStr,
        tasks: newTasks,
        updateEditDate: isRestrictedFieldsChanged,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プロフィールが更新されました！')),
        );
        Navigator.pop(context, true); // 変更があったことを伝えるためにtrueを返す
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存に失敗しました。もう一度お試しください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          PremiumBackground(),
          SafeArea(
            child: Column(
              children: [
                // Custom header row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'プロフィールを編集',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
                          if (_isRestricted)
                            Container(
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
                                      '名前以外の項目は、あと $_daysRemaining 日経過するまで変更できません。\n(次回変更可能目安: ${DateTime.now().add(Duration(days: _daysRemaining)).toString().split(' ')[0]})',
                                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Photo upload
                          Center(
                            child: GestureDetector(
                              onTap: _isRestricted ? null : _pickImage,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.12),
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
                                      backgroundImage: _newProfileImage != null
                                          ? FileImage(_newProfileImage!) as ImageProvider
                                          : (_currentPhotoUrl != null ? NetworkImage(_currentPhotoUrl!) : null),
                                      child: (_newProfileImage == null && _currentPhotoUrl == null)
                                          ? const Icon(Icons.person, size: 50, color: AppColors.textMuted)
                                          : null,
                                    ),
                                    if (!_isRestricted)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.camera_alt, color: AppColors.black, size: 20),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Section: Basic Info
                          const SectionTitle(title: '基本情報'),
                          const SizedBox(height: 12),

                          // Username
                          TextFormField(
                            controller: _usernameCtrl,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: '名前',
                              prefixIcon: Icon(Icons.badge, color: AppColors.textMuted),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? '名前を入力してください' : null,
                          ),
                          const SizedBox(height: 16),

                          // User ID
                          TextFormField(
                            controller: _userIdCtrl,
                            enabled: !_isRestricted,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'ユーザーID',
                              prefixIcon: Icon(Icons.alternate_email, color: AppColors.textMuted),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'ユーザーIDを入力してください';
                              final adminEmails = [
                                'ren0930ren0930@gmail.com',
                                'y.katahara.academia@gmail.com'
                              ];
                              final isSpecialAdmin = adminEmails.contains(FirebaseAuth.instance.currentUser?.email);
                              if (!isSpecialAdmin) {
                                if (v.trim().length < 5) return '5文字以上で入力してください';
                                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) return '英数字とアンダースコアのみ使えます';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Birth Date
                          const SectionTitle(title: '生年月日'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<int>(
                                  value: _birthYear, // ignore: deprecated_member_use
                                  dropdownColor: AppColors.bgElevated,
                                  style: const TextStyle(color: AppColors.textPrimary),
                                  decoration: const InputDecoration(labelText: '年'),
                                  items: List.generate(100, (i) => currentYear - i)
                                      .map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                                  onChanged: _isRestricted ? null : (v) => setState(() {
                                    _birthYear = v;
                                    if (_birthMonth != null && _birthDay != null) {
                                      final maxDay = _daysInMonth(_birthYear!, _birthMonth!);
                                      if (_birthDay! > maxDay) _birthDay = maxDay;
                                    }
                                  }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<int>(
                                  value: _birthMonth, // ignore: deprecated_member_use
                                  dropdownColor: AppColors.bgElevated,
                                  style: const TextStyle(color: AppColors.textPrimary),
                                  decoration: const InputDecoration(labelText: '月'),
                                  items: List.generate(12, (i) => i + 1)
                                      .map((m) => DropdownMenuItem(value: m, child: Text('$m'))).toList(),
                                  onChanged: _isRestricted ? null : (v) => setState(() {
                                    _birthMonth = v;
                                    if (_birthYear != null && _birthDay != null) {
                                      final maxDay = _daysInMonth(_birthYear!, _birthMonth!);
                                      if (_birthDay! > maxDay) _birthDay = maxDay;
                                    }
                                  }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<int>(
                                  value: _birthDay, // ignore: deprecated_member_use
                                  dropdownColor: AppColors.bgElevated,
                                  style: const TextStyle(color: AppColors.textPrimary),
                                  decoration: const InputDecoration(labelText: '日'),
                                  items: List.generate(
                                    (_birthYear != null && _birthMonth != null) ? _daysInMonth(_birthYear!, _birthMonth!) : 31,
                                    (i) => i + 1,
                                  ).map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
                                  onChanged: _isRestricted ? null : (v) => setState(() => _birthDay = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Wake up and Task Time
                          const SectionTitle(title: '毎日のルーティン'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.alarm),
                                  label: Text(
                                    _wakeUpTime != null ? _formatTimeOfDay(_wakeUpTime!) : '起床時間',
                                    style: TextStyle(
                                      color: _wakeUpTime != null ? AppColors.textPrimary : AppColors.textMuted,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    alignment: Alignment.centerLeft,
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.border),
                                  ),
                                  onPressed: _isRestricted ? null : () => _pickTime(true),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.schedule),
                                  label: Text(
                                    _taskTime != null ? _formatTimeOfDay(_taskTime!) : 'タスク時間',
                                    style: TextStyle(
                                      color: _taskTime != null ? AppColors.textPrimary : AppColors.textMuted,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    alignment: Alignment.centerLeft,
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.border),
                                  ),
                                  onPressed: _isRestricted ? null : () => _pickTime(false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Tasks
                          const SectionTitle(title: 'やりたいタスク（1〜5個）'),
                          const SizedBox(height: 12),
                          ...List.generate(_taskCtrls.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _taskCtrls[index],
                                      style: const TextStyle(color: AppColors.textPrimary),
                                      decoration: InputDecoration(
                                        labelText: 'タスク ${index + 1}',
                                        hintText: '例: ランニング3km',
                                        hintStyle: const TextStyle(color: AppColors.textMuted),
                                      ),
                                    ),
                                  ),
                                  if (_taskCtrls.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                                      onPressed: () => _removeTaskField(index),
                                    ),
                                ],
                              ),
                            );
                          }),
                          if (_taskCtrls.length < 5)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                icon: const Icon(Icons.add, color: AppColors.primary),
                                label: const Text('タスクを追加', style: TextStyle(color: AppColors.primary)),
                                onPressed: _addTaskField,
                              ),
                            ),

                          const SizedBox(height: 48),

                          // Save button
                          GradientButton(
                            onPressed: _saveProfile,
                            isLoading: _isSaving,
                            child: const Text('保存する'),
                          ),
                          const SizedBox(height: 24),
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
    );
  }
}
