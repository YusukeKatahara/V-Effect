import UIKit
import google_mobile_ads

@objc(CustomNativeAdView)
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
        self.clipsToBounds = true // 境界外にはみ出たアセットの描画を防ぐ（AdMobバリデータ対策）
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

        // ボタン以外のUI要素のインタラクションを無効化して、タッチをFlutterの親ビューに透過させる
        customMediaView.isUserInteractionEnabled = false
        customHeadlineLabel.isUserInteractionEnabled = false
        customBodyLabel.isUserInteractionEnabled = false
        customIconImageView.isUserInteractionEnabled = false

        // データの割り当て
        customMediaView.mediaContent = nativeAd.mediaContent
        
        // 見出しのフォントとシャドウ設定 (通常投稿の名前と同じ14sp, Bold)
        customHeadlineLabel.text = nativeAd.headline
        customHeadlineLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        customHeadlineLabel.textColor = .white
        customHeadlineLabel.layer.shadowColor = UIColor.black.cgColor
        customHeadlineLabel.layer.shadowRadius = 4.0
        customHeadlineLabel.layer.shadowOpacity = 0.6
        customHeadlineLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        customHeadlineLabel.layer.masksToBounds = false
        
        // 説明文のフォントとシャドウ設定 (通常投稿のキャプションと同じ15sp, Regular)
        if let body = nativeAd.body {
            customBodyLabel.text = body
            customBodyLabel.isHidden = false
            customBodyLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
            customBodyLabel.textColor = .white
            customBodyLabel.layer.shadowColor = UIColor.black.cgColor
            customBodyLabel.layer.shadowRadius = 4.0
            customBodyLabel.layer.shadowOpacity = 0.6
            customBodyLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
            customBodyLabel.layer.masksToBounds = false
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

        // 動的なアバター制約調整と円形化
        let widthConstraint = customIconImageView.constraints.first(where: { $0.firstAttribute == .width })
        let heightConstraint = customIconImageView.constraints.first(where: { $0.firstAttribute == .height })
        let textStack = customHeadlineLabel.superview
        let spacingConstraint = customIconImageView.superview?.constraints.first(where: {
            ($0.firstItem as? UIView == textStack && $0.secondItem as? UIView == customIconImageView) ||
            ($0.secondItem as? UIView == textStack && $0.firstItem as? UIView == customIconImageView)
        })

        if let icon = nativeAd.icon {
            customIconImageView.image = icon.image
            customIconImageView.isHidden = false
            customIconImageView.layer.cornerRadius = 16 // 32x32の円
            customIconImageView.clipsToBounds = true
            
            widthConstraint?.constant = 32
            heightConstraint?.constant = 32
            spacingConstraint?.constant = 8
        } else {
            customIconImageView.isHidden = true
            widthConstraint?.constant = 0
            heightConstraint?.constant = 0
            spacingConstraint?.constant = 0
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
