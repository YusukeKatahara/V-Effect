import 'dart:io';
import 'package:flutter/foundation.dart';

class AdHelper {
  // アプリID
  static String get appId {
    if (Platform.isAndroid) {
      // TODO: Android本番用アプリIDを取得したらここを書き換える
      return 'ca-app-pub-3940256099942544~3347511713';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-8663290040582485~9566655984';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // ネイティブ広告ユニットID
  static String get nativeAdUnitId {
    // デバッグ（開発）中は自己クリックによるアカウントBANを防ぐため、必ずテスト用IDを返す
    if (kDebugMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/2247696110'; // Google提供のAndroid用テストネイティブ広告ID
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/3986624511'; // Google提供のiOS用テストネイティブ広告ID
      }
    }
    
    // リリース（本番）用ID
    if (Platform.isAndroid) {
      // TODO: Android本番用広告ユニットIDを取得したらここを書き換える
      return 'ca-app-pub-3940256099942544/2247696110';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-8663290040582485/4574183755';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
}
