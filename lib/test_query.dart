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
    print('Testing query...');
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('userId', isEqualTo: 'test_user_id_12345')
        .limit(1)
        .get();
    print('Query succeeded! isEmpty: \${query.docs.isEmpty}');
    for (var doc in query.docs) {
      print('Doc ID: \${doc.id}, Data: \${doc.data()}');
    }
  } catch (e, st) {
    print('Query failed with error: $e');
    print('StackTrace: $st');
  }
}
