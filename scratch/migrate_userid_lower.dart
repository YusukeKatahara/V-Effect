import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// 全ユーザーの userIdLower フィールドを更新するマイグレーションスクリプト
/// 開発環境で一度だけ実行することを想定
Future<void> migrateUserIdLower() async {
  final db = FirebaseFirestore.instance;
  final usersSnap = await db.collection('users').get();
  
  print('${usersSnap.docs.length} 人のユーザーを処理中...');
  
  int updatedCount = 0;
  final batch = db.batch();
  
  for (var i = 0; i < usersSnap.docs.length; i++) {
    final doc = usersSnap.docs[i];
    final data = doc.data();
    final userId = data['userId'] as String?;
    
    if (userId != null) {
      batch.update(doc.reference, {
        'userIdLower': userId.toLowerCase(),
      });
      updatedCount++;
    }
    
    // Batch limit is 500
    if ((i + 1) % 400 == 0) {
      await batch.commit();
      print('${i + 1} 件処理完了...');
    }
  }
  
  await batch.commit();
  print('完了: $updatedCount 件のユーザーに userIdLower を追加しました。');
}
