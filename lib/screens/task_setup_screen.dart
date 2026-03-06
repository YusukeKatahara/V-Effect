import 'package:flutter/material.dart';
import '../config/routes.dart';
import '../services/user_service.dart';

/// 新規登録後のタスク設定画面（Step 2/2）
/// タスク（1〜5個）、起床時間、タスク実行時間を入力します
class TaskSetupScreen extends StatefulWidget {
  const TaskSetupScreen({super.key});

  @override
  State<TaskSetupScreen> createState() => _TaskSetupScreenState();
}

class _TaskSetupScreenState extends State<TaskSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  bool _isSaving = false;

  // タスク入力欄（最初は1つ、最大5つまで追加可能）
  final List<TextEditingController> _taskCtrls = [TextEditingController()];

  // 起床時間とタスク実行時間
  TimeOfDay _wakeUpTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _taskTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
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

  Future<void> _pickTime({required bool isWakeUp}) async {
    final initial = isWakeUp ? _wakeUpTime : _taskTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isWakeUp) {
          _wakeUpTime = picked;
        } else {
          _taskTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _saveAndFinish() async {
    if (!_formKey.currentState!.validate()) return;

    final tasks = _taskCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タスクを1つ以上入力してください')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _userService.saveTaskSettings(
        tasks: tasks,
        wakeUpTime: _formatTime(_wakeUpTime),
        taskTime: _formatTime(_taskTime),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
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

              // ── タスク入力欄 ──
              const Text(
                'タスク（1〜5個）',
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
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.redAccent),
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

              // ── 起床時間 ──
              const Text(
                'いつも何時に起きますか？',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
