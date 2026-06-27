import Foundation
import google_mobile_ads

class MyNativeAdFactory: NSObject, FLTNativeAdFactory {
    func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable : Any]?) -> NativeAdView? {
        // CustomNativeAdView.xibファイルからレイアウトを読み込み
        guard let nibViews = Bundle.main.loadNibNamed("CustomNativeAdView", owner: nil, options: nil),
              let nativeAdView = nibViews.first as? CustomNativeAdView else {
            return nil
        }

        // 広告のテキストや動画コントローラの設定（初期消音、ミュートボタン設定など）を呼び出し
        nativeAdView.populate(with: nativeAd)

        return nativeAdView
    }
}
