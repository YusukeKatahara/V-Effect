import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/routes.dart';
import '../services/user_service.dart';

/// 新規登録後のタスク設定画面（Step 2/2）
/// プロフィール写真、タスク（1〜5個）、タスク実行時間、起床時間を入力します
class TaskSetupScreen extends StatefulWidget {
  const TaskSetupScreen({super.key});

  @override
  State<TaskSetupScreen> createState() => _TaskSetupScreenState();
}

class _TaskSetupScreenState extends State<TaskSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  bool _isSaving = false;

  // プロフィール写真
  File? _profileImage;
  final _picker = ImagePicker();

  // タスク入力欄（最初は1つ、最大5つまで追加可能）
  final List<TextEditingController> _taskCtrls = [TextEditingController()];

  // タスク実行時間と起床時間
  TimeOfDay _taskTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _wakeUpTime = const TimeOfDay(hour: 7, minute: 0);

  @override
  void dispose() {
    for (final ctrl in _taskCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
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

  /// 【rennさんへ】
  /// iPhoneの設定画面みたいに、スクロールで時間を選べるピッカーを表示します。
  /// 画面の下からスルッと出てきて、上下にクルクル回して選ぶやつです。
  Future<void> _pickTime({required bool isWakeUp}) async {
    final initial = isWakeUp ? _wakeUpTime : _taskTime;
    // 一時的に選択中の時・分を保持する変数
    int selectedHour = initial.hour;
    int selectedMinute = initial.minute;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: 320,
              child: Column(
                children: [
                  // ── ヘッダー部分：タイトルと「完了」ボタン ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('キャンセル'),
                        ),
                        Text(
                          isWakeUp ? '起きる時間' : 'タスクの時間',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // 「完了」を押したら、選んだ時間を確定して閉じる
                            setState(() {
                              final newTime = TimeOfDay(
                                hour: selectedHour,
                                minute: selectedMinute,
                              );
                              if (isWakeUp) {
                                _wakeUpTime = newTime;
                              } else {
                                _taskTime = newTime;
                              }
                            });
                            Navigator.pop(context);
                          },
                          child: const Text(
                            '完了',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // ── スクロールホイール部分 ──
                  Expanded(
                    child: Row(
                      children: [
                        // 「時」のホイール（0〜23時）
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 48,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            controller: FixedExtentScrollController(
                              initialItem: selectedHour,
                            ),
                            onSelectedItemChanged: (index) {
                              setModalState(() => selectedHour = index);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 24,
                              builder: (context, index) {
                                final isSelected = index == selectedHour;
                                return Center(
                                  child: Text(
                                    '$index時',
                                    style: TextStyle(
                                      fontSize: isSelected ? 22 : 16,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      color:
                                          isSelected
                                              ? Colors.amber
                                              : Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // 「分」のホイール（0〜59分、5分刻み）
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 48,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            controller: FixedExtentScrollController(
                              initialItem: selectedMinute ~/ 5,
                            ),
                            onSelectedItemChanged: (index) {
                              setModalState(() => selectedMinute = index * 5);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 12, // 0, 5, 10, ... 55
                              builder: (context, index) {
                                final minute = index * 5;
                                final isSelected = minute == selectedMinute;
                                return Center(
                                  child: Text(
                                    '${minute.toString().padLeft(2, '0')}分',
                                    style: TextStyle(
                                      fontSize: isSelected ? 22 : 16,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      color:
                                          isSelected
                                              ? Colors.amber
                                              : Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 時間を「午前 7:00」「午後 9:00」のような日本語形式で画面に表示します
  String _formatTime(TimeOfDay time) {
    final period = time.hour < 12 ? '午前' : '午後';
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    return '$period $h:$m';
  }

  /// Firestoreに保存する用の24時間形式（例: "07:00"）
  String _formatTimeForSave(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// プロフィール画像を Firebase Storage にアップロードして URL を返す
  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return null;
    return await _userService.uploadProfileImage(_profileImage!);
  }

  Future<void> _saveAndFinish() async {
    if (!_formKey.currentState!.validate()) return;

    final tasks =
        _taskCtrls
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('タスクを1つ以上入力してください')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // プロフィール画像のアップロード
      String? photoUrl;
      if (!kIsWeb && _profileImage != null) {
        photoUrl = await _uploadProfileImage();
      }

      debugPrint('タスク保存開始: tasks=$tasks');
      debugPrint('wakeUpTime=${_formatTimeForSave(_wakeUpTime)}');
      debugPrint('taskTime=${_formatTimeForSave(_taskTime)}');

      await _userService.saveTaskSettings(
        tasks: tasks,
        wakeUpTime: _formatTimeForSave(_wakeUpTime),
        taskTime: _formatTimeForSave(_taskTime),
        photoUrl: photoUrl,
      );

      debugPrint('タスク保存成功！');

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.initialFriend);
      }
    } catch (e, stackTrace) {
      debugPrint('タスク保存エラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('タスク設定')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.task_alt, size: 80, color: Colors.amber),
              const SizedBox(height: 8),
              const Text(
                'Step 2 / 2',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              const Text(
                '日々のタスクとスケジュールを設定しましょう',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // ── プロフィール写真 ──
              const Text(
                'プロフィール写真',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: _pickProfileImage,
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                    child:
                        _profileImage == null
                            ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  size: 32,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '写真を選択',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            )
                            : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── タスク入力欄 ──
              const Text(
                'やりたいタスク（1〜5個）',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...List.generate(_taskCtrls.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _taskCtrls[index],
                          decoration: InputDecoration(
                            labelText: 'タスク ${index + 1}',
                            hintText: '例: ランニング3km',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      if (_taskCtrls.length > 1)
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.redAccent,
                          ),
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
                    icon: const Icon(Icons.add),
                    label: const Text('タスクを追加'),
                    onPressed: _addTaskField,
                  ),
                ),
              const SizedBox(height: 24),

              // ── 起床時間（先に聞く：朝のスケジュール順） ──
              const Text(
                'いつも何時に起きますか？',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'この時間に起床の通知をお届けします',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _pickTime(isWakeUp: true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.alarm),
                  ),
                  child: Text(
                    _formatTime(_wakeUpTime),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── タスク実行時間 ──
              const Text(
                'タスクをいつやりたいですか？',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'この時間に通知を送ってタスクをリマインドします',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _pickTime(isWakeUp: false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  child: Text(
                    _formatTime(_taskTime),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── 完了ボタン ──
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _saveAndFinish,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.amber.shade700,
                      textStyle: const TextStyle(fontSize: 17),
                    ),
                    child: const Text('設定を完了してはじめる'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
