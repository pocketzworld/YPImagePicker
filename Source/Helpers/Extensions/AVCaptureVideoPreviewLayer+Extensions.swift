import AVKit

extension AVCaptureVideoPreviewLayer {

    func applyUIOrientation() {
        switch UIInterfaceOrientation.current {
        case .landscapeLeft:
            self.connection?.videoOrientation = .landscapeLeft
        case .landscapeRight:
            self.connection?.videoOrientation = .landscapeRight
        case .portraitUpsideDown:
            self.connection?.videoOrientation = .portraitUpsideDown
        @unknown default:
            self.connection?.videoOrientation = .portrait
        }
    }

}
