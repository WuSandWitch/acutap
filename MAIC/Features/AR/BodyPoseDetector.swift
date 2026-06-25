//
//  BodyPoseDetector.swift
//  MAIC
//
//  Created by Luis on 2026/6/25.
//
//  支援三種偵測模式：
//   - fullBody  → 全身可見，投影到身體 bounding box
//   - faceOnly  → 只有臉部，投影到臉 bounding box
//   - none      → 數學 fallback

import SwiftUI
import Vision
import AVFoundation

// MARK: - 偵測模式

enum DetectionMode: Equatable {
    /// 全身（≥6 關節點）
    case fullBody
    /// 只有臉部（沒偵測到身體，但有臉）
    case faceOnly
    /// 無任何偵測
    case none

    var label: String {
        switch self {
        case .fullBody: "全身"
        case .faceOnly: "臉部"
        case .none: "—"
        }
    }
}

// MARK: - 人體 + 臉部偵測資料

enum HandSide: String { case left, right }

struct DetectedBody: Equatable {
    /// 身體 bounding box（正規化 0…1）
    let boundingBox: CGRect
    /// 各關節在畫面中的正規化位置
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    /// 臉部 bounding box（如果有的話）
    let faceRect: CGRect?
    /// 臉部關鍵點
    let faceLandmarks: FaceLandmarkPoints?
    /// 手部關節點（左手 / 右手）
    let handJoints: [HandSide: [VNHumanHandPoseObservation.JointName: CGPoint]]

    // MARK: 輔助屬性

    var width: CGFloat { boundingBox.width }
    var height: CGFloat { boundingBox.height }
    var midX: CGFloat { boundingBox.midX }
    var topY: CGFloat { boundingBox.minY }
    var bottomY: CGFloat { boundingBox.maxY }

    /// 當前偵測模式
    var detectionMode: DetectionMode {
        let bodyCount = joints.count
        if bodyCount >= 3 { return .fullBody }
        if faceRect != nil { return .faceOnly }
        return .none
    }

    var isFacingCamera: Bool {
        joints[.leftShoulder] != nil && joints[.rightShoulder] != nil
    }

    // MARK: 身體穴位投影

    /// 將穴位 bodyPoint 投影到螢幕（使用身體 bounding box）
    func project(_ bodyPoint: BodyPoint, viewSize: CGSize) -> CGPoint {
        let nx: CGFloat
        let ny: CGFloat
        ny = boundingBox.minY + bodyPoint.y * boundingBox.height

        switch bodyPoint.side {
        case .front:
            nx = boundingBox.minX + bodyPoint.x * boundingBox.width
        case .back:
            nx = boundingBox.minX + (1 - bodyPoint.x) * boundingBox.width
        }

        return CGPoint(x: nx * viewSize.width, y: ny * viewSize.height)
    }

    // MARK: 臉部穴位投影

    /// 臉部在全身上的 Y 範圍（頭頂≈0.02, 下巴≈0.15）
    private static let faceYRange: ClosedRange<CGFloat> = 0.02...0.15

    /// 將臉部穴位 bodyPoint 投影到臉部 bounding box
    func projectFace(_ bodyPoint: BodyPoint, viewSize: CGSize) -> CGPoint? {
        guard let faceRect else { return nil }
        let faceH = Self.faceYRange.upperBound - Self.faceYRange.lowerBound

        // 把全域 bodyPoint.y 重新正規化到臉部範圍內
        let fy = max(0, min(1, (bodyPoint.y - Self.faceYRange.lowerBound) / faceH))

        let nx: CGFloat
        switch bodyPoint.side {
        case .front:
            nx = bodyPoint.x
        case .back:
            nx = 1 - bodyPoint.x
        }

        let screenX = (faceRect.minX + nx * faceRect.width) * viewSize.width
        let screenY = (faceRect.minY + fy * faceRect.height) * viewSize.height
        return CGPoint(x: screenX, y: screenY)
    }

    /// 取得特定關節在 View 上的位置
    func jointPosition(_ joint: VNHumanBodyPoseObservation.JointName, viewSize: CGSize) -> CGPoint? {
        guard let pt = joints[joint] else { return nil }
        return CGPoint(x: pt.x * viewSize.width, y: pt.y * viewSize.height)
    }

    /// 判斷穴位是否為臉部穴位（Y < 0.15）
    static func isFaceAcupoint(_ bodyPoint: BodyPoint) -> Bool {
        bodyPoint.y < faceYRange.upperBound
    }

    // MARK: - Vision 關節點定位（取代 bounding box）

    /// 使用 Vision 關節點計算穴位在螢幕上的位置
    /// 比 bounding box 投影準確，因為適應每個人實際體型
    func projectUsingJoints(acupointID: String, bodyPoint: BodyPoint, viewSize: CGSize) -> CGPoint? {
        guard let rule = acupointJointRules[acupointID] else { return nil }

        // 取得 proximal/distal 關節位置
        guard let pPos = joints[rule.proximal],
              let dPos = joints[rule.distal] else {
            // 找不到關節時 fallback
            return nil
        }

        // 沿骨骼線性插值
        let r = CGFloat(rule.ratio)
        var x = pPos.x + (dPos.x - pPos.x) * r
        var y = pPos.y + (dPos.y - pPos.y) * r

        // 側向偏移（垂直於骨骼方向）
        if rule.lateralOffset != 0 {
            let dx = dPos.x - pPos.x
            let dy = dPos.y - pPos.y
            let len = sqrt(dx*dx + dy*dy)
            if len > 0.001 {
                let nx = -dy / len  // 垂直向量
                let ny = dx / len
                let off = CGFloat(rule.lateralOffset) * 0.15  // 偏移量
                x += nx * off
                y += ny * off
            }
        }

        return CGPoint(x: x * viewSize.width, y: y * viewSize.height)
    }

    /// 混合投影：有關節規則就用關節點定位，否則用 bounding box
    func smartProject(acupoint: Acupoint, viewSize: CGSize) -> CGPoint {
        // 0. 嘗試手部穴位定位（用 Vision Hand Pose）
        if let handRule = handAcupointRules[acupoint.id] {
            // 找左右手哪隻有這個關節
            for (_, handJts) in handJoints {
                if let pos = handJts[handRule.refJoint] {
                    let x = (pos.x + CGFloat(handRule.dx)) * viewSize.width
                    let y = (pos.y + CGFloat(handRule.dy)) * viewSize.height
                    return CGPoint(x: x, y: y)
                }
            }
        }

        // 1. 嘗試關節點定位（最準確）
        if let pos = projectUsingJoints(acupointID: acupoint.id,
                                         bodyPoint: acupoint.bodyPoint,
                                         viewSize: viewSize) {
            return pos
        }

        // 2. 臉部穴位用臉部 box
        if Self.isFaceAcupoint(acupoint.bodyPoint),
           let facePos = projectFace(acupoint.bodyPoint, viewSize: viewSize) {
            return facePos
        }

        // 3. 全身 bounding box（fallback）
        return project(acupoint.bodyPoint, viewSize: viewSize)
    }
}

// MARK: - 臉部關鍵點

struct FaceLandmarkPoints: Equatable {
    /// 鼻子尖端
    let nose: CGPoint?
    /// 左眼中心
    let leftEye: CGPoint?
    /// 右眼中心
    let rightEye: CGPoint?
    /// 嘴巴中心
    let mouth: CGPoint?
    /// 臉部輪廓點
    let contour: [CGPoint]?

    /// 取眼眉頭之間的中點（近似印堂）
    var glabella: CGPoint? {
        guard let l = leftEye, let r = rightEye else { return nil }
        return CGPoint(x: (l.x + r.x) / 2, y: (l.y + r.y) / 2)
    }
}

// MARK: - 人體姿勢 + 臉部偵測器

@Observable
final class BodyPoseDetector: @unchecked Sendable {
    /// 目前偵測到的結果
    private(set) var detectedBody: DetectedBody?
    /// 是否正在偵測中
    private(set) var isDetecting = false
    /// 目前偵測模式（便利屬性）
    var detectionMode: DetectionMode { detectedBody?.detectionMode ?? .none }

    // — Vision 請求 —
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private let faceRectRequest = VNDetectFaceRectanglesRequest()
    private let faceLandmarksRequest = VNDetectFaceLandmarksRequest()
    private let handPoseRequest = VNDetectHumanHandPoseRequest()

    private let visionQueue = DispatchQueue(label: "acutap.vision.pose", qos: .userInitiated)

    // MARK: 處理 Frame

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard !isDetecting else { return }
        isDetecting = true

        visionQueue.async { [weak self] in
            guard let self = self else { return }
            defer { DispatchQueue.main.async { self.isDetecting = false } }

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                orientation: .rightMirrored,
                                                options: [:])

            do {
                // 同時跑人體 + 臉部 + 手部偵測
                try handler.perform([self.poseRequest, self.faceRectRequest, self.faceLandmarksRequest, self.handPoseRequest])

                let body = self.buildDetectedBody(
                    pose: self.poseRequest.results?.first,
                    faceObservations: self.faceRectRequest.results,
                    faceLandmarkObservations: self.faceLandmarksRequest.results,
                    handObservations: self.handPoseRequest.results
                )

                DispatchQueue.main.async {
                    self.detectedBody = body
                }
            } catch {
                DispatchQueue.main.async {
                    self.detectedBody = nil
                }
            }
        }
    }

    // MARK: 建立 DetectedBody

    private func buildDetectedBody(
        pose: VNHumanBodyPoseObservation?,
        faceObservations: [VNFaceObservation]?,
        faceLandmarkObservations: [VNFaceObservation]?,
        handObservations: [VNHumanHandPoseObservation]?
    ) -> DetectedBody {
        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        var minX: CGFloat = 1, maxX: CGFloat = 0
        var minY: CGFloat = 1, maxY: CGFloat = 0

        // — 身體關節 —
        let allJoints: [VNHumanBodyPoseObservation.JointName] = [
            .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle,
            .root,
            .leftEar, .rightEar
        ]

        if let pose = pose {
            for joint in allJoints {
                if let point = try? pose.recognizedPoint(joint),
                   point.confidence > 0.3 {
                    let loc = point.location
                    joints[joint] = loc
                    minX = min(minX, loc.x)
                    maxX = max(maxX, loc.x)
                    minY = min(minY, loc.y)
                    maxY = max(maxY, loc.y)
                }
            }
        }

        // — 臉部偵測 —
        var faceRect: CGRect? = faceObservations?.first?.boundingBox
        var faceLM: FaceLandmarkPoints?

        if let face = faceLandmarkObservations?.first,
           let landmarks = face.landmarks {
            func point(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
                guard let pts = region?.pointsInImage(imageSize: CGSize(width: 1, height: 1)),
                      !pts.isEmpty else { return nil }
                let avg = pts.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
                return CGPoint(x: avg.x / CGFloat(pts.count), y: avg.y / CGFloat(pts.count))
            }

            faceLM = FaceLandmarkPoints(
                nose: point(landmarks.nose),
                leftEye: point(landmarks.leftEye),
                rightEye: point(landmarks.rightEye),
                mouth: point(landmarks.outerLips),
                contour: landmarks.faceContour?.pointsInImage(imageSize: CGSize(width: 1, height: 1)).map {
                    CGPoint(x: $0.x, y: $0.y)
                }
            )

            // 如果沒有身體關節但有臉，用臉的 bounding box 當參考
            if joints.isEmpty, let faceRect {
                minX = faceRect.minX
                maxX = faceRect.maxX
                minY = faceRect.minY
                maxY = faceRect.maxY
            }
        }

        // — 手部關節 —
        var handJoints: [HandSide: [VNHumanHandPoseObservation.JointName: CGPoint]] = [:]
        if let hands = handObservations {
            for observation in hands {
                let side: HandSide = observation.chirality == .left ? .left : .right
                var joints: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
                let allHandJoints: [VNHumanHandPoseObservation.JointName] = [
                    .wrist, .thumbTip, .thumbIP, .thumbMP, .thumbCMC,
                    .indexTip, .indexDIP, .indexPIP, .indexMCP,
                    .middleTip, .middleDIP, .middlePIP, .middleMCP,
                    .ringTip, .ringDIP, .ringPIP, .ringMCP,
                    .littleTip, .littleDIP, .littlePIP, .littleMCP,
                ]
                for joint in allHandJoints {
                    if let point = try? observation.recognizedPoint(joint), point.confidence > 0.3 {
                        joints[joint] = point.location
                    }
                }
                if !joints.isEmpty {
                    handJoints[side] = joints
                }
            }
        }

        // — bounding box —
        guard !joints.isEmpty || faceRect != nil else {
            return DetectedBody(boundingBox: .zero, joints: [:], faceRect: nil, faceLandmarks: nil, handJoints: [:])
        }

        let padX = joints.isEmpty ? 0 : (maxX - minX) * 0.08
        let padY = joints.isEmpty ? 0 : (maxY - minY) * 0.05

        let bbox = CGRect(
            x: max(0, minX - padX),
            y: max(0, minY - padY),
            width: min(1, maxX - minX + padX * 2),
            height: min(1, maxY - minY + padY * 2)
        )

        return DetectedBody(
            boundingBox: bbox,
            joints: joints,
            faceRect: faceRect,
            faceLandmarks: faceLM,
            handJoints: handJoints
        )
    }
}

// MARK: - 偵測到人體時的修飾詞

extension View {
    /// 根據偵測模式智能顯示穴位 overlay
    func bodyPoseOverlay(detector: BodyPoseDetector,
                         acupoints: [Acupoint],
                         viewSize: CGSize,
                         activePointID: String? = nil) -> some View {
        self.overlay(alignment: .topLeading) {
            if let body = detector.detectedBody, body.boundingBox != .zero {
                let visiblePoints = filterVisible(acupoints, for: body.detectionMode)

                ZStack {
                    // 經絡連線
                    if visiblePoints.count > 1 {
                        Path { path in
                            let pts = visiblePoints.compactMap { a -> CGPoint? in
                                position(for: a, body: body, viewSize: viewSize)
                            }
                            guard let first = pts.first else { return }
                            path.move(to: first)
                            for pt in pts.dropFirst() { path.addLine(to: pt) }
                        }
                        .stroke(Color.teal.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 6]))
                    }

                    // 穴位標記
                    ForEach(visiblePoints, id: \.id) { point in
                        if let pos = position(for: point, body: body, viewSize: viewSize) {
                            let isActive = point.id == activePointID
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(isActive ? Color.teal : Color.teal.opacity(0.6))
                                    .frame(width: isActive ? 28 : 18, height: isActive ? 28 : 18)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.8), lineWidth: isActive ? 3 : 1.5)
                                    )
                                    .shadow(color: Color.teal.opacity(isActive ? 0.8 : 0.3), radius: isActive ? 12 : 4)
                                Text(point.nameZh)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
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

    /// 依模式過濾穴位
    private func filterVisible(_ points: [Acupoint], for mode: DetectionMode) -> [Acupoint] {
        switch mode {
        case .fullBody:
            return points  // 全身都顯示
        case .faceOnly:
            return points.filter { DetectedBody.isFaceAcupoint($0.bodyPoint) }
        case .none:
            return []
        }
    }

    /// 根據模式選擇投影方式
    private func position(for acupoint: Acupoint, body: DetectedBody, viewSize: CGSize) -> CGPoint? {
        switch body.detectionMode {
        case .fullBody:
            return body.project(acupoint.bodyPoint, viewSize: viewSize)
        case .faceOnly:
            if DetectedBody.isFaceAcupoint(acupoint.bodyPoint) {
                return body.projectFace(acupoint.bodyPoint, viewSize: viewSize)
            }
            return nil
        case .none:
            return nil
        }
    }
}
