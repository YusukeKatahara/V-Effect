import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';

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
    super.dispose();
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

    final newUserId = _userIdCtrl.text.trim();
    final newUsername = _usernameCtrl.text.trim();
    final birthDateStr = '${_birthYear!}-${_birthMonth!.toString().padLeft(2, '0')}-${_birthDay!.toString().padLeft(2, '0')}';
    final wakeUpTimeStr = _formatTimeOfDay(_wakeUpTime!);
    final taskTimeStr = _formatTimeOfDay(_taskTime!);

    bool isRestrictedFieldsChanged = false;
    
    if (newUserId != widget.user.userId ||
        _newProfileImage != null ||
        birthDateStr != widget.privateData['birthDate'] ||
        wakeUpTimeStr != widget.privateData['wakeUpTime'] ||
        taskTimeStr != widget.privateData['taskTime']) {
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
          title: const Text('確認'),
          content: const Text('この変更を保存すると、名前以外のプロフィール項目は今後90日間変更できなくなります。\n\n本当によろしいですか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
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
          SnackBar(content: Text('保存に失敗しました: $e')),
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
      appBar: AppBar(title: const Text('プロフィールを編集')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '名前以外の項目は、あと $_daysRemaining 日経過するまで変更できません。\n(次回変更可能目安: ${DateTime.now().add(Duration(days: _daysRemaining)).toString().split(' ')[0]})',
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Photo upload
              Center(
                child: GestureDetector(
                  onTap: _isRestricted ? null : _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage: _newProfileImage != null
                            ? FileImage(_newProfileImage!) as ImageProvider
                            : (_currentPhotoUrl != null ? NetworkImage(_currentPhotoUrl!) : null),
                        child: (_newProfileImage == null && _currentPhotoUrl == null)
                            ? const Icon(Icons.person, size: 50, color: Colors.grey)
                            : null,
                      ),
                      if (!_isRestricted)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Username
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: '名前',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '名前を入力してください' : null,
              ),
              const SizedBox(height: 16),

              // User ID
              TextFormField(
                controller: _userIdCtrl,
                enabled: !_isRestricted,
                decoration: const InputDecoration(
                  labelText: 'ユーザーID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'ユーザーIDを入力してください';
                  if (v.trim().length < 5) return '5文字以上で入力してください';
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) return '英数字とアンダースコアのみ使えます';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Birth Date
              const Text('生年月日', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      value: _birthYear,
                      decoration: const InputDecoration(labelText: '年', border: OutlineInputBorder()),
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
                      value: _birthMonth,
                      decoration: const InputDecoration(labelText: '月', border: OutlineInputBorder()),
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
                      value: _birthDay,
                      decoration: const InputDecoration(labelText: '日', border: OutlineInputBorder()),
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
              const Text('毎日のルーティン', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.alarm),
                      label: Text(_wakeUpTime != null ? _formatTimeOfDay(_wakeUpTime!) : '起床時間'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: _isRestricted ? null : () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text(_taskTime != null ? _formatTimeOfDay(_taskTime!) : 'タスク時間'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: _isRestricted ? null : () => _pickTime(false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // Save button
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 17),
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('保存する'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
