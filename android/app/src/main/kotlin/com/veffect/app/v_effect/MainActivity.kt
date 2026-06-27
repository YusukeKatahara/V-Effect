package com.veffect.app.v_effect

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // カスタム広告ファクトリを "customNativeAd" というIDで登録
        val factory = MyNativeAdFactory(layoutInflater)
        GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "customNativeAd", factory)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)

        // リソースリークを防ぐため、エンジン破棄時に登録解除
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "customNativeAd")
    }
}

