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

// MARK: - 手部穴位定位規則（使用 Vision Hand Pose 21 點）

/// 手部穴位：使用 HandJointName 定位
struct HandJointRule {
    let refJoint: VNHumanHandPoseObservation.JointName
    let dx: Double  // 相對於關節的 x 偏移 (0-1)
    let dy: Double
}

let handAcupointRules: [String: HandJointRule] = [
    // 合谷：拇指與食指掌骨之間 → 介於 thumbCMC 與 indexMCP 之間
    "LI4":  .init(refJoint: .indexMCP,  dx: -0.03, dy: -0.01),
    // 少商：拇指指甲外側 → thumbTip 稍微偏移
    "LU11": .init(refJoint: .thumbTip,  dx: -0.02, dy: -0.01),
    // 商陽：食指指甲外側 → indexTip 偏移
    "LI1":  .init(refJoint: .indexTip,  dx: 0.02,  dy: -0.01),
    // 少衝：小指指甲外側 → littleTip
    "HT9":  .init(refJoint: .littleTip, dx: -0.02, dy: -0.01),
    // 少澤：小指指甲外側 → littleTip
    "SI1":  .init(refJoint: .littleTip, dx: 0.02,  dy: -0.01),
    // 中衝：中指指尖 → middleTip
    "PC9":  .init(refJoint: .middleTip, dx: 0.0,   dy: -0.01),
    // 關衝：無名指指甲外側 → ringTip
    "TE1":  .init(refJoint: .ringTip,   dx: 0.02,  dy: -0.01),
    // 後谿：手背小指側 → littleMCP
    "SI3":  .init(refJoint: .littleMCP, dx: -0.02, dy: -0.01),
    // 腕骨：手腕 → wrist
    "SI4":  .init(refJoint: .wrist,     dx: 0.0,   dy: 0.0),
]

// MARK: - 雙側穴位（左右都有）

/// 這些穴位在人體左右兩側都存在
let bilateralAcupoints: Set<String> = [
    "LI4", "LI10", "LI11", "LI1", "LI2", "LI3", "LI5", "LI6", "LI7", "LI8", "LI9", "LI12", "LI13", "LI14", "LI15", "LI16", "LI17", "LI18", "LI19", "LI20",
    "LU5", "LU7", "LU9", "LU11", "LU1", "LU2", "LU3", "LU4", "LU6", "LU8", "LU10",
    "ST36", "ST40", "ST37", "ST39", "ST25", "ST1", "ST2", "ST3", "ST4", "ST5", "ST6", "ST7", "ST8", "ST9", "ST10", "ST11", "ST12", "ST13", "ST14", "ST15",
    "SP6", "SP9", "SP1", "SP2", "SP3", "SP4", "SP5", "SP7", "SP8", "SP10", "SP11",
    "HT7", "HT1", "HT2", "HT3", "HT4", "HT5", "HT6", "HT8", "HT9",
    "SI3", "SI4", "SI11", "SI9", "SI1", "SI2", "SI5", "SI6", "SI7", "SI8", "SI10",
    "BL40", "BL60", "BL13", "BL23", "BL57", "BL1", "BL2", "BL10", "BL11", "BL12",
    "KI3", "KI1", "KI2", "KI4", "KI5", "KI6", "KI7", "KI8", "KI9", "KI10",
    "PC6", "PC9", "PC7", "PC8", "PC1", "PC2", "PC3", "PC4", "PC5",
    "TE5", "TE1", "TE2", "TE3", "TE4", "TE6", "TE7", "TE8", "TE9", "TE10",
    "GB34", "GB30", "GB39", "GB20", "GB21", "GB1", "GB2", "GB3", "GB4",
    "LV3", "LV1", "LV2", "LV4", "LV5", "LV6", "LV7", "LV8", "LV9",
]

// MARK: - 缺失關節警告

/// 左↔右鏡像關節映射
func mirroredJoint(_ joint: VNHumanBodyPoseObservation.JointName) -> VNHumanBodyPoseObservation.JointName? {
    let map: [VNHumanBodyPoseObservation.JointName: VNHumanBodyPoseObservation.JointName] = [
        .leftShoulder: .rightShoulder, .rightShoulder: .leftShoulder,
        .leftElbow: .rightElbow, .rightElbow: .leftElbow,
        .leftWrist: .rightWrist, .rightWrist: .leftWrist,
        .leftHip: .rightHip, .rightHip: .leftHip,
        .leftKnee: .rightKnee, .rightKnee: .leftKnee,
        .leftAnkle: .rightAnkle, .rightAnkle: .leftAnkle,
        .leftEar: .rightEar, .rightEar: .leftEar,
    ]
    return map[joint]
}

/// 判斷某個穴位需要哪些關節才能定位
func requiredJointsForAcupoint(_ id: String) -> [String] {
    if handAcupointRules[id] != nil { return ["手掌"] }
    guard let rule = acupointJointRules[id] else { return [] }
    let names: [VNHumanBodyPoseObservation.JointName: String] = [
        .neck:"頸", .root:"髖", .leftShoulder:"左肩", .rightShoulder:"右肩",
        .leftElbow:"左肘", .rightElbow:"右肘", .leftWrist:"左腕", .rightWrist:"右腕",
        .leftHip:"左髖", .rightHip:"右髖", .leftKnee:"左膝", .rightKnee:"右膝",
        .leftAnkle:"左踝", .rightAnkle:"右踝",
    ]
    var result: [String] = []
    if let n = names[rule.proximal] { result.append(n) }
    if let n = names[rule.distal], n != result.last { result.append(n) }
    return result
}

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
