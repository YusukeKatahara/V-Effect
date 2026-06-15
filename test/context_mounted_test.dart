import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 1. StatefulWidgetでのmountedチェック
class SafeStatefulWidget extends StatefulWidget {
  final Future<void> Function() asyncTask;
  final VoidCallback onComplete;

  const SafeStatefulWidget({
    super.key,
    required this.asyncTask,
    required this.onComplete,
  });

  @override
  State<SafeStatefulWidget> createState() => _SafeStatefulWidgetState();
}

class _SafeStatefulWidgetState extends State<SafeStatefulWidget> {
  bool _isLoading = false;

  Future<void> _runTask() async {
    setState(() => _isLoading = true);
    await widget.asyncTask();
    
    // 対策: 非同期処理の後にmountedチェックを行う
    if (!mounted) return;
    
    setState(() => _isLoading = false);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _runTask,
      child: Text(_isLoading ? 'Loading' : 'Start'),
    );
  }
}

// 2. StatelessWidgetでのcontext.mountedチェック
class SafeStatelessWidget extends StatelessWidget {
  final Future<void> Function() asyncTask;
  final Function(BuildContext) onComplete;

  const SafeStatelessWidget({
    super.key,
    required this.asyncTask,
    required this.onComplete,
  });

  Future<void> _runTask(BuildContext context) async {
    await asyncTask();
    
    // 対策: 非同期処理の後にcontext.mountedチェックを行う
    if (!context.mounted) return;
    
    onComplete(context);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _runTask(context),
      child: const Text('Start'),
    );
  }
}

class UnsafeWidget extends StatefulWidget {
  final Future<void> Function() asyncTask;
  final VoidCallback onComplete;
  final Function(Future<void>)? onTaskStarted;

  const UnsafeWidget({
    super.key,
    required this.asyncTask,
    required this.onComplete,
    this.onTaskStarted,
  });

  @override
  State<UnsafeWidget> createState() => _UnsafeWidgetState();
}

class _UnsafeWidgetState extends State<UnsafeWidget> {
  bool _isLoading = false;

  Future<void> _runTask() async {
    setState(() => _isLoading = true);
    await widget.asyncTask();
    
    // 対策なし
    setState(() => _isLoading = false);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final future = _runTask();
        widget.onTaskStarted?.call(future);
      },
      child: Text(_isLoading ? 'Loading' : 'Start'),
    );
  }
}

void main() {
  group('BuildContext & State Mounted Verification Tests', () {
    testWidgets('UnsafeWidget should throw an assertion error when setState is called after unmount', (WidgetTester tester) async {
      final completer = FutureCompleter();
      late Future<void> taskFuture;

      // ウィジェットのビルド
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnsafeWidget(
              asyncTask: () => completer.future,
              onComplete: () {},
              onTaskStarted: (future) {
                taskFuture = future;
              },
            ),
          ),
        ),
      );

      // タスク開始
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(); // setState()を反映

      expect(find.text('Loading'), findsOneWidget);

      // 非同期タスク完了前にウィジェットをアンマウント (新しいUIに置き換える)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Gone'),
          ),
        ),
      );

      // 非同期タスクを完了させる
      completer.complete();

      // 非同期でのsetState呼び出しによる例外が発生することを確認する
      expect(taskFuture, throwsA(isA<FlutterError>()));

      // イベントループとフレーム描画を回す
      await tester.pumpAndSettle();
    });

    testWidgets('SafeStatefulWidget should NOT throw any error when state is checked with mounted after unmount', (WidgetTester tester) async {
      final completer = FutureCompleter();
      bool onCompleteCalled = false;

      // ウィジェットのビルド
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeStatefulWidget(
              asyncTask: () => completer.future,
              onComplete: () {
                onCompleteCalled = true;
              },
            ),
          ),
        ),
      );

      // タスク開始
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Loading'), findsOneWidget);

      // 非同期タスク完了前にウィジェットをアンマウント
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Gone'),
          ),
        ),
      );

      // 非同期タスクを完了させる
      completer.complete();

      // 処理を完了させる
      await tester.pumpAndSettle();

      // 例外が発生していないことを確認
      expect(tester.takeException(), null);
      // ウィジェットがアンマウントされているため、onCompleteは呼ばれないはず
      expect(onCompleteCalled, isFalse);
    });

    testWidgets('SafeStatelessWidget should NOT throw any error when context is checked with context.mounted after unmount', (WidgetTester tester) async {
      final completer = FutureCompleter();
      bool onCompleteCalled = false;

      // ウィジェットのビルド
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeStatelessWidget(
              asyncTask: () => completer.future,
              onComplete: (context) {
                onCompleteCalled = true;
                // ここでcontextを使用しても例外が発生しない(呼ばれないため)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Completed')),
                );
              },
            ),
          ),
        ),
      );

      // タスク開始
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // 非同期タスク完了前にウィジェットをアンマウント
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Gone'),
          ),
        ),
      );

      // 非同期タスクを完了させる
      completer.complete();

      // 処理を完了させる
      await tester.pumpAndSettle();

      // 例外が発生していないことを確認
      expect(tester.takeException(), null);
      // ウィジェットがアンマウントされているため、onCompleteは呼ばれないはず
      expect(onCompleteCalled, isFalse);
    });
  });
}

// 簡易的なFutureコントロール用のヘルパークラス
class FutureCompleter {
  late final Function() complete;
  late final Future<void> future;

  FutureCompleter() {
    var isDone = false;
    final callbacks = <Function()>[];
    future = Future(() async {
      while (!isDone) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      for (final cb in callbacks) {
        cb();
      }
    });
    complete = () {
      isDone = true;
    };
  }
}
