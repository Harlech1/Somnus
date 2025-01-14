import MediaPlayer
import UIKit

class VolumeManager {
    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?
    static let shared = VolumeManager()
    
    init() {
        setupVolumeControl()
    }
    
    private func setupVolumeControl() {
        volumeView = MPVolumeView(frame: CGRect.zero)
        if let view = volumeView {
            view.isHidden = true
            UIApplication.shared.windows.first?.addSubview(view)
            
            for subview in view.subviews {
                if let slider = subview as? UISlider {
// set this to 1.0 on release.
// slider.value = 0.3
                    volumeSlider = slider
                    break
                }
            }
        }
    }
    
    func setVolume(to value: Float = 0.3) {
        DispatchQueue.main.async {
            self.volumeSlider?.setValue(value, animated: false)
            self.volumeSlider?.sendActions(for: .touchUpInside)
        }
    }
}
