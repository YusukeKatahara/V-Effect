import UIKit
import google_mobile_ads

class CustomNativeAdView: NativeAdView {
    @IBOutlet weak var customMediaView: MediaView!
    @IBOutlet weak var customHeadlineLabel: UILabel!
    @IBOutlet weak var customBodyLabel: UILabel!
    @IBOutlet weak var customCallToActionButton: UIButton!
    @IBOutlet weak var customIconImageView: UIImageView!
    @IBOutlet weak var customMuteButton: UIButton!
    @IBOutlet weak var gradientView: UIView!

    private var videoController: VideoController?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupGradient()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 画面サイズ変更に合わせてグラデーションレイヤーのサイズを自動追従させる
        gradientView.layer.sublayers?.first?.frame = gradientView.bounds
    }

    private func setupGradient() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.9).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = gradientView.bounds
        gradientView.layer.addSublayer(gradientLayer)
    }

    func populate(with nativeAd: NativeAd) {
        self.nativeAd = nativeAd
        self.videoController = nativeAd.mediaContent.videoController

        // GADNativeAdView標準のアウトレットにバインド
        self.mediaView = customMediaView
        self.headlineView = customHeadlineLabel
        self.bodyView = customBodyLabel
        self.callToActionView = customCallToActionButton
        self.iconView = customIconImageView

        // データの割り当て
        customMediaView.mediaContent = nativeAd.mediaContent
        customHeadlineLabel.text = nativeAd.headline
        
        if let body = nativeAd.body {
            customBodyLabel.text = body
            customBodyLabel.isHidden = false
        } else {
            customBodyLabel.isHidden = true
        }

        if let cta = nativeAd.callToAction {
            customCallToActionButton.setTitle(cta, for: .normal)
            customCallToActionButton.isHidden = false
            
            // UIデザインの最適化 (ゴールドボタン・角丸)
            customCallToActionButton.layer.cornerRadius = 18
            customCallToActionButton.clipsToBounds = true
            customCallToActionButton.backgroundColor = UIColor(red: 212/255.0, green: 175/255.0, blue: 55/255.0, alpha: 1.0)
            customCallToActionButton.setTitleColor(.white, for: .normal)
        } else {
            customCallToActionButton.isHidden = true
        }

        if let icon = nativeAd.icon {
            customIconImageView.image = icon.image
            customIconImageView.isHidden = false
            customIconImageView.layer.cornerRadius = 20
            customIconImageView.clipsToBounds = true
        } else {
            customIconImageView.isHidden = true
        }

        // ビデオの初期ミュート制御
        if let vc = videoController, nativeAd.mediaContent.hasVideoContent {
            vc.isMuted = true
            updateMuteButtonImage(isMuted: true)
            customMuteButton.isHidden = false
            
            customMuteButton.layer.cornerRadius = 18
            customMuteButton.clipsToBounds = true
            customMuteButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        } else {
            customMuteButton.isHidden = true
        }
    }

    @IBAction func didTapMuteButton(_ sender: UIButton) {
        guard let vc = videoController else { return }
        let currentMute = vc.isMuted
        let newMute = !currentMute
        vc.isMuted = newMute
        updateMuteButtonImage(isMuted: newMute)
    }

    private func updateMuteButtonImage(isMuted: Bool) {
        let imageName = isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        if let image = UIImage(systemName: imageName) {
            customMuteButton.setImage(image, for: .normal)
            customMuteButton.tintColor = .white
        }
    }
}
