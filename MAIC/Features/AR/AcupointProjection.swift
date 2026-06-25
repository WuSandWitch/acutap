//
//  AcupointProjection.swift
//  MAIC
//
//  Vision 關節點定位 — 取代 bounding box 投影
//  將 bankroz 的 MediaPipe 骨骼比例直接對應到 Vision 關節
//

import Foundation
import Vision

// MARK: - MediaPipe → Vision Joint 映射

let mediapipeToVision: [Int: VNHumanBodyPoseObservation.JointName] = [
    11: .leftShoulder, 12: .rightShoulder,
    13: .leftElbow,   14: .rightElbow,
    15: .leftWrist,   16: .rightWrist,
    23: .leftHip,     24: .rightHip,
    25: .leftKnee,    26: .rightKnee,
    27: .leftAnkle,   28: .rightAnkle,
]

// MARK: - 穴位骨骼定位規則

struct JointRule {
    let proximal: VNHumanBodyPoseObservation.JointName
    let distal: VNHumanBodyPoseObservation.JointName
    let ratio: Double          // 0=proximal, 1=distal
    let lateralOffset: Double  // 側向偏移 (正規化)
}

/// 有準確骨骼定位資料的穴位（62 個 bankroz 核心穴）
let acupointJointRules: [String: JointRule] = {
    // 從 bankroz 資料集轉換
    // ratio: 沿骨骼的比例, lateralOffset: 側向偏移
    [
        // ── 上肢 ──
        "LI11": .init(proximal: .rightElbow,  distal: .rightWrist, ratio: 0.00, lateralOffset: 0.04),
        "LI10": .init(proximal: .rightElbow,  distal: .rightWrist, ratio: 0.30, lateralOffset: 0.03),
        "LI4":  .init(proximal: .rightWrist,  distal: .rightEar,   ratio: 0.10, lateralOffset: 0.02),
        "LU5":  .init(proximal: .leftElbow,   distal: .leftWrist,  ratio: 0.00, lateralOffset: 0.03),
        "LU7":  .init(proximal: .leftElbow,   distal: .leftWrist,  ratio: 0.75, lateralOffset: 0.02),
        "LU9":  .init(proximal: .leftElbow,   distal: .leftWrist,  ratio: 0.95, lateralOffset: 0.01),
        "PC6":  .init(proximal: .rightElbow,  distal: .rightWrist, ratio: 0.80, lateralOffset: -0.02),
        "HT7":  .init(proximal: .leftElbow,   distal: .leftWrist,  ratio: 0.95, lateralOffset: -0.03),
        "TE5":  .init(proximal: .rightElbow,  distal: .rightWrist, ratio: 0.80, lateralOffset: 0.02),
        "LU11": .init(proximal: .leftWrist,   distal: .leftEar,    ratio: 0.15, lateralOffset: 0.01),

        // ── 下肢 ──
        "ST36": .init(proximal: .rightKnee,   distal: .rightAnkle, ratio: 0.25, lateralOffset: 0.03),
        "ST37": .init(proximal: .rightKnee,   distal: .rightAnkle, ratio: 0.50, lateralOffset: 0.03),
        "ST39": .init(proximal: .rightKnee,   distal: .rightAnkle, ratio: 0.75, lateralOffset: 0.03),
        "ST40": .init(proximal: .rightKnee,   distal: .rightAnkle, ratio: 0.55, lateralOffset: 0.02),
        "SP6":  .init(proximal: .leftKnee,    distal: .leftAnkle,  ratio: 0.80, lateralOffset: -0.02),
        "SP9":  .init(proximal: .leftKnee,    distal: .leftAnkle,  ratio: 0.15, lateralOffset: -0.03),
        "KI3":  .init(proximal: .leftKnee,    distal: .leftAnkle,  ratio: 0.95, lateralOffset: -0.01),
        "BL40": .init(proximal: .leftKnee,    distal: .leftAnkle,  ratio: 0.00, lateralOffset: 0.00),
        "BL60": .init(proximal: .leftKnee,    distal: .leftAnkle,  ratio: 0.98, lateralOffset: 0.02),
        "GB34": .init(proximal: .rightKnee,   distal: .rightAnkle, ratio: 0.10, lateralOffset: 0.04),
        "GB30": .init(proximal: .leftHip,     distal: .leftKnee,   ratio: 0.05, lateralOffset: 0.05),
        "GB39": .init(proximal: .rightKnee,   distal: .rightAnkle, ratio: 0.70, lateralOffset: 0.03),
        "LV3":  .init(proximal: .leftKnee,    distal: .leftAnkle,  ratio: 0.98, lateralOffset: -0.01),
        "ST41": .init(proximal: .rightKnee,   distal: .rightAnkle, ratio: 0.85, lateralOffset: 0.02),
        "BL57": .init(proximal: .rightKnee,   distal: .rightAnkle, ratio: 0.60, lateralOffset: 0.01),

        // ── 軀幹 ──
        "CV17": .init(proximal: .neck,        distal: .root,       ratio: 0.25, lateralOffset: 0.00),
        "CV12": .init(proximal: .neck,        distal: .root,       ratio: 0.45, lateralOffset: 0.00),
        "CV6":  .init(proximal: .neck,        distal: .root,       ratio: 0.60, lateralOffset: 0.00),
        "CV4":  .init(proximal: .neck,        distal: .root,       ratio: 0.65, lateralOffset: 0.00),
        "ST25": .init(proximal: .neck,        distal: .root,       ratio: 0.55, lateralOffset: 0.04),
        "GV14": .init(proximal: .neck,        distal: .root,       ratio: 0.20, lateralOffset: 0.00),
        "GV4":  .init(proximal: .neck,        distal: .root,       ratio: 0.60, lateralOffset: 0.00),
        "BL13": .init(proximal: .neck,        distal: .root,       ratio: 0.28, lateralOffset: -0.03),
        "BL15": .init(proximal: .neck,        distal: .root,       ratio: 0.33, lateralOffset: -0.03),
        "BL18": .init(proximal: .neck,        distal: .root,       ratio: 0.45, lateralOffset: -0.03),
        "BL20": .init(proximal: .neck,        distal: .root,       ratio: 0.50, lateralOffset: -0.03),
        "BL23": .init(proximal: .neck,        distal: .root,       ratio: 0.60, lateralOffset: -0.03),
        "GB21": .init(proximal: .neck,        distal: .rightShoulder, ratio: 0.50, lateralOffset: 0.00),

        // ── 頭頸 ──
        "GV20": .init(proximal: .neck,        distal: .leftEar,    ratio: 0.10, lateralOffset: 0.00),
        "GB20": .init(proximal: .neck,        distal: .leftEar,    ratio: 0.40, lateralOffset: -0.04),
    ]
}()

// MARK: - 穴位區域分類

enum AcupointRegion {
    case head, arm, torso, leg
}

func regionForAcupoint(_ id: String, bodyPoint: BodyPoint) -> AcupointRegion {
    // 有 joint rule 的用 proximal joint 判斷
    if let rule = acupointJointRules[id] {
        switch rule.proximal {
        case .leftElbow, .rightElbow, .leftWrist, .rightWrist:
            return .arm
        case .leftKnee, .rightKnee, .leftAnkle, .rightAnkle:
            return .leg
        case .neck, .root, .leftHip, .rightHip, .leftShoulder, .rightShoulder:
            return .torso
        default:
            break
        }
    }
    // fallback: 用 bodyPoint y 判斷
    if bodyPoint.y < 0.15 { return .head }
    if bodyPoint.y < 0.50 { return .torso }
    if bodyPoint.y < 0.60 { return .torso }
    return .leg
}
