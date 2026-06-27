package com.veffect.app.v_effect

import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MyNativeAdFactory(private val layoutInflater: LayoutInflater) : GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.custom_native_ad, null) as NativeAdView

        // 1. UIコンポーネントをバインド（結びつけ）
        adView.mediaView = adView.findViewById<MediaView>(R.id.ad_media)
        adView.headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        adView.bodyView = adView.findViewById<TextView>(R.id.ad_body)
        adView.callToActionView = adView.findViewById<Button>(R.id.ad_call_to_action)
        adView.iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)

        // 2. 広告データをUIに反映
        adView.mediaView?.setMediaContent(nativeAd.mediaContent)

        (adView.headlineView as TextView).text = nativeAd.headline

        if (nativeAd.body == null) {
            adView.bodyView?.visibility = View.INVISIBLE
        } else {
            adView.bodyView?.visibility = View.VISIBLE
            (adView.bodyView as TextView).text = nativeAd.body
        }

        if (nativeAd.callToAction == null) {
            adView.callToActionView?.visibility = View.INVISIBLE
        } else {
            adView.callToActionView?.visibility = View.VISIBLE
            (adView.callToActionView as Button).text = nativeAd.callToAction
        }

        if (nativeAd.icon == null) {
            adView.iconView?.visibility = View.GONE
        } else {
            (adView.iconView as ImageView).setImageDrawable(nativeAd.icon?.drawable)
            adView.iconView?.visibility = View.VISIBLE
            adView.iconView?.clipToOutline = true
        }

        // 3. 動画コントローラのミュート（消音）制御
        val muteButton = adView.findViewById<ImageView>(R.id.ad_mute_button)
        val vc = nativeAd.mediaContent?.videoController

        if (vc != null && vc.hasVideoContent()) {
            // 初期値は消音状態でスタート
            vc.mute(true)
            // 標準のミュートアイコン（スピーカーに斜線）を表示
            muteButton.setImageResource(android.R.drawable.ic_lock_silent_mode)
            muteButton.visibility = View.VISIBLE

            muteButton.setOnClickListener {
                val newMute = !vc.isMuted
                vc.mute(newMute)
                if (newMute) {
                    muteButton.setImageResource(android.R.drawable.ic_lock_silent_mode)
                } else {
                    muteButton.setImageResource(android.R.drawable.ic_lock_silent_mode_off)
                }
            }
        } else {
            // 動画がない広告の場合はミュートボタン自体を非表示
            muteButton.visibility = View.GONE
        }

        // 広告本体をNativeAdViewに登録
        adView.setNativeAd(nativeAd)

        return adView
    }
}
