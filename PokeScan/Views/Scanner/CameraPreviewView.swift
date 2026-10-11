import SwiftUI
import AVFoundation

public struct CameraPreviewView: UIViewRepresentable {
    public let captureSession: AVCaptureSession
    
    public init(captureSession: AVCaptureSession) {
        self.captureSession = captureSession
    }
    
    public func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.videoPreviewLayer.session = captureSession
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    public func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Aggiorna orientamento se necessario
    }
}

public class CameraPreviewUIView: UIView {
    public override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    public var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
