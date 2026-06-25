//
//  CameraPreview.swift
//  MAIC
//
//  Created by Luis on 2026/5/30.
//

import SwiftUI
import AVFoundation

/// 前鏡頭擷取控制器（AR 點穴用 + 人體姿勢偵測）
@Observable
final class CameraController: NSObject {
    enum Status { case idle, running, denied, unavailable }

    let session = AVCaptureSession()
    var status: Status = .idle

    /// 人體姿勢偵測器
    let poseDetector = BodyPoseDetector()

    private let queue = DispatchQueue(label: "acutap.camera.session")
    private var configured = false

    /// 是否能顯示即時影像
    var isLive: Bool { status == .running }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureAndRun() }
                    else { self?.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    private func configureAndRun() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                // — 相機輸入 —
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                           for: .video, position: .front),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.status = .unavailable }
                    return
                }
                self.session.addInput(input)

                // — 影片資料輸出（給 Vision 做人體偵測）—
                let videoOutput = AVCaptureVideoDataOutput()
                videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                videoOutput.setSampleBufferDelegate(self, queue: self.visionQueue)
                videoOutput.alwaysDiscardsLateVideoFrames = true
                if self.session.canAddOutput(videoOutput) {
                    self.session.addOutput(videoOutput)
                }

                // — 方向校正（前鏡頭要 mirror）—
                if let connection = videoOutput.connection(with: .video) {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = true
                    }
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }

                self.session.commitConfiguration()
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.status = .running }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - Vision 處理佇列

    private let visionQueue = DispatchQueue(label: "acutap.vision.output",
                                            qos: .userInitiated)
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        poseDetector.processFrame(sampleBuffer)
    }
}

// MARK: - SwiftUI 預覽 Layer

/// 將 AVCaptureSession 餵給一個 AVCaptureVideoPreviewLayer
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        // 前鏡頭要 mirror — 先關閉自動調整
        if let connection = view.previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
