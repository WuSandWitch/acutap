//
//  BodyPoseDetector.swift
//  MAIC
//
//  Created by Luis on 2026/6/25.
//

import SwiftUI
import Vision
import AVFoundation

// MARK: - 人體關節點資料

struct DetectedBody: Equatable {
    /// 在畫面中的正規化 bounding box（0…1）
    let boundingBox: CGRect
    /// 各關節在畫面中的正規化位置
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]

    /// 身體寬度（用於判斷人體大小 / 距離）
    var width: CGFloat { boundingBox.width }
    /// 身體高度
    var height: CGFloat { boundingBox.height }
    /// 人體中軸 X（左右肩的中點）
    var midX: CGFloat { boundingBox.midX }
    /// 頭頂 Y
    var topY: CGFloat { boundingBox.minY }
    /// 腳底 Y
    var bottomY: CGFloat { boundingBox.maxY }

    /// 是否為正向面對鏡頭
    var isFacingCamera: Bool {
        // 左右肩都偵測到且寬度 > 高度的一定比例 → 正面
        joints[.leftShoulder] != nil && joints[.rightShoulder] != nil
    }

    /// 是否為背面
    var isBackToCamera: Bool {
        !isFacingCamera
    }

    /// 取得特定位置（身體部位）在螢幕上的 CGPoint
    /// - Parameters:
    ///   - bodyPoint: 穴位定義的 BodyPoint（side, x: 0~1, y: 0~1）
    ///   - viewSize: 目前 View 的尺寸（pt）
    /// - Returns: 在 View 上的位置（pt）
    func project(_ bodyPoint: BodyPoint, viewSize: CGSize) -> CGPoint {
        let nx: CGFloat
        let ny: CGFloat

        // y: 從頭頂(0)到腳底(1)
        ny = boundingBox.minY + bodyPoint.y * boundingBox.height

        // x: 根據 side 處理左右映射
        switch bodyPoint.side {
        case .front:
            // 正面：x:0 = 身體左側, x:1 = 身體右側
            nx = boundingBox.minX + bodyPoint.x * boundingBox.width
        case .back:
            // 背面：x:0 = 身體右側（因為從背後看左右相反）
            nx = boundingBox.minX + (1 - bodyPoint.x) * boundingBox.width
        }

        return CGPoint(
            x: nx * viewSize.width,
            y: ny * viewSize.height
        )
    }

    /// 取得特定關節在 View 上的位置
    func jointPosition(_ joint: VNHumanBodyPoseObservation.JointName, viewSize: CGSize) -> CGPoint? {
        guard let pt = joints[joint] else { return nil }
        return CGPoint(x: pt.x * viewSize.width, y: pt.y * viewSize.height)
    }
}

// MARK: - 人體姿勢偵測器

@Observable
final class BodyPoseDetector: @unchecked Sendable {
    /// 目前偵測到的人體（如果有的話）
    private(set) var detectedBody: DetectedBody?

    /// 是否正在偵測中
    private(set) var isDetecting = false

    /// 人體偵測請求
    private let poseRequest = VNDetectHumanBodyPoseRequest()

    /// Vision 請求處理器
    private let visionQueue = DispatchQueue(label: "acutap.vision.pose",
                                            qos: .userInitiated)

    /// 處理來自相機的 frame
    /// - Parameter sampleBuffer: 相機輸出的畫面
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard !isDetecting else { return }
        isDetecting = true

        visionQueue.async { [weak self] in
            guard let self = self else { return }
            defer { DispatchQueue.main.async { self.isDetecting = false } }

            let handler = VNImageRequestHandler(
                cvPixelBuffer: CMSampleBufferGetImageBuffer(sampleBuffer)!,
                orientation: .up,
                options: [:]
            )

            do {
                try handler.perform([self.poseRequest])
                guard let observation = self.poseRequest.results?.first else {
                    DispatchQueue.main.async {
                        self.detectedBody = nil
                    }
                    return
                }

                let body = self.buildDetectedBody(from: observation)
                DispatchQueue.main.async {
                    self.detectedBody = body
                }
            } catch {
                // Silently fail – no person in frame is normal
                DispatchQueue.main.async {
                    self.detectedBody = nil
                }
            }
        }
    }

    /// 從 Vision observation 建立 DetectedBody
    private func buildDetectedBody(from observation: VNHumanBodyPoseObservation) -> DetectedBody {
        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        var minX: CGFloat = 1, maxX: CGFloat = 0
        var minY: CGFloat = 1, maxY: CGFloat = 0

        // 取出所有已辨識的關節
        let allJoints: [VNHumanBodyPoseObservation.JointName] = [
            .head, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle,
            .spine, .root,
            .leftEar, .rightEar
        ]

        for joint in allJoints {
            if let point = try? observation.recognizedPoint(joint),
               point.confidence > 0.3 {
                let loc = point.location
                joints[joint] = loc
                minX = min(minX, loc.x)
                maxX = max(maxX, loc.x)
                minY = min(minY, loc.y)
                maxY = max(maxY, loc.y)
            }
        }

        // 如果沒有任何關節，回傳空的 body
        guard !joints.isEmpty else {
            return DetectedBody(boundingBox: .zero, joints: [:])
        }

        // 加入邊界 padding（讓穴位不要卡在邊緣）
        let padX = (maxX - minX) * 0.08
        let padY = (maxY - minY) * 0.05

        let bbox = CGRect(
            x: max(0, minX - padX),
            y: max(0, minY - padY),
            width: min(1, maxX - minX + padX * 2),
            height: min(1, maxY - minY + padY * 2)
        )

        return DetectedBody(boundingBox: bbox, joints: joints)
    }
}

// MARK: - 偵測到人體時的修飾詞

extension View {
    /// 當偵測到人體時顯示的 overlay
    func bodyPoseOverlay(detector: BodyPoseDetector,
                         acupoints: [Acupoint],
                         viewSize: CGSize,
                         activePointID: String? = nil) -> some View {
        self.overlay(alignment: .topLeading) {
            if let body = detector.detectedBody, body.boundingBox != .zero {
                ZStack {
                    // 經絡連線（穴位之間）
                    if acupoints.count > 1 {
                        Path { path in
                            let pts = acupoints.compactMap { a -> CGPoint? in
                                guard !a.id.isEmpty else { return nil }
                                return body.project(a.bodyPoint, viewSize: viewSize)
                            }
                            guard let first = pts.first else { return }
                            path.move(to: first)
                            for pt in pts.dropFirst() {
                                path.addLine(to: pt)
                            }
                        }
                        .stroke(Color.teal.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.5,
                                                   lineCap: .round,
                                                   dash: [2, 6]))
                    }

                    // 穴位標記
                    ForEach(acupoints, id: \.id) { point in
                        let pos = body.project(point.bodyPoint, viewSize: viewSize)
                        let isActive = point.id == activePointID

                        VStack(spacing: 4) {
                            Circle()
                                .fill(isActive ? Color.teal : Color.teal.opacity(0.6))
                                .frame(width: isActive ? 28 : 18, height: isActive ? 28 : 18)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.8), lineWidth: isActive ? 3 : 1.5)
                                )
                                .shadow(color: Color.teal.opacity(isActive ? 0.8 : 0.3),
                                        radius: isActive ? 12 : 4)

                            Text(point.nameZh)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .position(pos)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
    }
}
