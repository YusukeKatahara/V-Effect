import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    debugPrint('Testing query...');
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('userId', isEqualTo: 'test_user_id_12345')
        .limit(1)
        .get();
    debugPrint('Query succeeded! isEmpty: ${query.docs.isEmpty}');
    for (var doc in query.docs) {
      debugPrint('Doc ID: ${doc.id}, Data: ${doc.data()}');
    }
  } catch (e, st) {
    debugPrint('Query failed with error: $e');
    debugPrint('StackTrace: $st');
  }
}
