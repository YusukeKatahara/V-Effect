import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final db = FirebaseFirestore.instance;
  final snap = await db.collection('notifications')
      .where('type', isEqualTo: 'reactionReceived')
      .limit(10)
      .get();
      
  print('Found ${snap.docs.length} reactionReceived notifications');
  for (var doc in snap.docs) {
    print('${doc.id}: ${doc.data()}');
  }
}
