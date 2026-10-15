import Foundation
import AVFoundation
import UIKit

public protocol CameraFrameDelegate: AnyObject {
    func didCaptureFrame(_ sampleBuffer: CMSampleBuffer)
}

public class CameraManager: NSObject, ObservableObject {
    @Published public var isRunning = false
    @Published public var permissionDenied = false
    @Published public var isTorchOn = false
    
    public let captureSession = AVCaptureSession()
    public weak var frameDelegate: CameraFrameDelegate?
    
    private let sessionQueue = DispatchQueue(label: "com.pokescan.camera.session")
    private let outputQueue = DispatchQueue(label: "com.pokescan.camera.output", qos: .userInitiated)
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    public override init() {
        super.init()
    }
    
    public func checkPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupSession()
                    } else {
                        self.permissionDenied = true
                    }
                }
            }
        default:
            DispatchQueue.main.async {
                self.permissionDenied = true
            }
        }
    }
    
    private func setupSession() {
        sessionQueue.async {
            guard !self.captureSession.isRunning else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .hd1920x1080
            
            // Trova la fotocamera posteriore ottimale (macro o wide angle)
            let deviceTypes: [AVCaptureDevice.DeviceType] = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ]
            
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: .back
            )
            
            guard let videoDevice = discovery.devices.first else {
                print("[CameraManager] Nessuna fotocamera posteriore trovata")
                self.captureSession.commitConfiguration()
                return
            }
            
            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.captureSession.canAddInput(videoInput) {
                    self.captureSession.addInput(videoInput)
                    self.videoDeviceInput = videoInput
                }
                
                // Configura autofocus continuo, autoesposizione e framerate a 30 FPS per massima efficienza batteria
                try videoDevice.lockForConfiguration()
                if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                    videoDevice.focusMode = .continuousAutoFocus
                }
                if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
                    videoDevice.exposureMode = .continuousAutoExposure
                }
                if videoDevice.isAutoFocusRangeRestrictionSupported {
                    videoDevice.autoFocusRangeRestriction = .near // Ottimizzato per carte vicine
                }
                // Fissa il sensore a 30 FPS: dimezza il consumo energetico e azzera il surriscaldamento
                videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                videoDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                videoDevice.unlockForConfiguration()
                
                // Configura output video per Apple Vision
                let videoOutput = AVCaptureVideoDataOutput()
                videoOutput.alwaysDiscardsLateVideoFrames = true
                videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
                ]
                videoOutput.setSampleBufferDelegate(self, queue: self.outputQueue)
                
                if self.captureSession.canAddOutput(videoOutput) {
                    self.captureSession.addOutput(videoOutput)
                    
                    if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }
                
                self.captureSession.commitConfiguration()
                self.startSession()
                
            } catch {
                print("[CameraManager] Errore configurazione camera: \(error)")
                self.captureSession.commitConfiguration()
            }
        }
    }
    
    public func startSession() {
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = true
                }
            }
        }
    }
    
    public func stopSession() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }
    
    public func toggleTorch() {
        guard let device = videoDeviceInput?.device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if device.torchMode == .on {
                device.torchMode = .off
                DispatchQueue.main.async { self.isTorchOn = false }
            } else {
                try device.setTorchModeOn(level: 0.8)
                DispatchQueue.main.async { self.isTorchOn = true }
            }
            device.unlockForConfiguration()
        } catch {
            print("[CameraManager] Errore torcia: \(error)")
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameDelegate?.didCaptureFrame(sampleBuffer)
    }
}
