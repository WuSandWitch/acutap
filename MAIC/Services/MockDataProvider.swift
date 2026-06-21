import Foundation

@Observable
final class MockDataProvider {
    static let shared = MockDataProvider()

    let allAcupoints: [Acupoint]
    let currentSolarTerm: SolarTerm
    private(set) var weeklyVitals: [VitalSnapshot]

    private init() {
        self.allAcupoints = MockDataProvider.seedAcupoints()
        self.currentSolarTerm = SolarTerm(
            name: "小滿",
            climateTag: "濕氣漸盛",
            advice: "宜清淡飲食、適度運動以化濕，避免久坐傷脾。可常按 足三里、三陰交 健運脾胃。"
        )
        self.weeklyVitals = MockDataProvider.seedVitals()
    }

    var latestVital: VitalSnapshot { weeklyVitals.last! }

    private static func seedAcupoints() -> [Acupoint] {
        [
            .init(id: "LI4", nameZh: "合谷", pinyin: "Hé Gǔ",
                  meridian: "手陽明大腸經",
                  location: "手背第一、二掌骨間，第二掌骨橈側中點。",
                  indications: ["頭痛", "牙痛", "肩頸僵硬"],
                  pressSeconds: 30,
                  bodyPoint: .init(side: .front, x: 0.20, y: 0.52)),
            .init(id: "LV3", nameZh: "太衝", pinyin: "Tài Chōng",
                  meridian: "足厥陰肝經",
                  location: "足背第一、二蹠骨間，蹠骨結合部前方凹陷處。",
                  indications: ["疏肝解鬱", "頭痛", "失眠"],
                  pressSeconds: 30,
                  bodyPoint: .init(side: .front, x: 0.42, y: 0.94)),
            .init(id: "PC6", nameZh: "內關", pinyin: "Nèi Guān",
                  meridian: "手厥陰心包經",
                  location: "前臂掌側，腕橫紋上 2 寸，兩筋之間。",
                  indications: ["胸悶", "心悸", "助眠"],
                  pressSeconds: 30,
                  bodyPoint: .init(side: .front, x: 0.24, y: 0.48)),
            .init(id: "ST36", nameZh: "足三里", pinyin: "Zú Sān Lǐ",
                  meridian: "足陽明胃經",
                  location: "外膝眼下 3 寸，脛骨外側一橫指。",
                  indications: ["健脾", "增強免疫", "疲倦"],
                  pressSeconds: 45,
                  bodyPoint: .init(side: .front, x: 0.56, y: 0.76)),
            .init(id: "SP6", nameZh: "三陰交", pinyin: "Sān Yīn Jiāo",
                  meridian: "足太陰脾經",
                  location: "內踝尖上 3 寸，脛骨內側緣後方。",
                  indications: ["婦科", "失眠", "脾胃"],
                  pressSeconds: 30,
                  bodyPoint: .init(side: .front, x: 0.44, y: 0.86)),
            .init(id: "HT7", nameZh: "神門", pinyin: "Shén Mén",
                  meridian: "手少陰心經",
                  location: "腕橫紋尺側端，尺側腕屈肌腱橈側凹陷處。",
                  indications: ["安神", "失眠", "焦慮"],
                  pressSeconds: 30,
                  bodyPoint: .init(side: .front, x: 0.78, y: 0.50)),
            .init(id: "GB20", nameZh: "風池", pinyin: "Fēng Chí",
                  meridian: "足少陽膽經",
                  location: "後頸枕骨下，胸鎖乳突肌與斜方肌之間凹陷。",
                  indications: ["頭痛", "頸僵", "目眩"],
                  pressSeconds: 30,
                  bodyPoint: .init(side: .back, x: 0.56, y: 0.16)),
            .init(id: "GV20", nameZh: "百會", pinyin: "Bǎi Huì",
                  meridian: "督脈",
                  location: "頭頂正中線，兩耳尖連線中點。",
                  indications: ["提神", "頭痛", "安神"],
                  pressSeconds: 30,
                  bodyPoint: .init(side: .back, x: 0.50, y: 0.07)),
            .init(id: "BL23", nameZh: "腎俞", pinyin: "Shèn Shū",
                  meridian: "足太陽膀胱經",
                  location: "第二腰椎棘突下，旁開 1.5 寸。",
                  indications: ["腰痠", "疲倦", "補腎"],
                  pressSeconds: 45,
                  bodyPoint: .init(side: .back, x: 0.56, y: 0.48)),
            .init(id: "LU7", nameZh: "列缺", pinyin: "Liè Quē",
                  meridian: "手太陰肺經",
                  location: "前臂橈側，腕橫紋上 1.5 寸。",
                  indications: ["咳嗽", "頭項痛", "鼻塞"],
                  pressSeconds: 30,
                  bodyPoint: .init(side: .front, x: 0.18, y: 0.50)),
            .init(id: "CV17", nameZh: "膻中", pinyin: "Dàn Zhōng",
                  meridian: "任脈",
                  location: "胸骨正中線，兩乳頭連線中點。",
                  indications: ["胸悶", "氣短", "情志不暢"],
                  pressSeconds: 30,
                  bodyPoint: .init(side: .front, x: 0.50, y: 0.30)),
            .init(id: "GB21", nameZh: "肩井", pinyin: "Jiān Jǐng",
                  meridian: "足少陽膽經",
                  location: "肩部，大椎與肩峰連線中點。",
                  indications: ["肩頸僵硬", "頭痛"],
                  pressSeconds: 30,
                  bodyPoint: .init(side: .back, x: 0.34, y: 0.22)),
            .init(id: "BL13", nameZh: "肺俞", pinyin: "Fèi Shū",
                  meridian: "足太陽膀胱經",
                  location: "第三胸椎棘突下，旁開 1.5 寸。",
                  indications: ["咳嗽", "胸悶", "背部痠痛"],
                  pressSeconds: 30,
                  bodyPoint: .init(side: .back, x: 0.56, y: 0.30)),
            .init(id: "GB30", nameZh: "環跳", pinyin: "Huán Tiào",
                  meridian: "足少陽膽經",
                  location: "臀部，股骨大轉子與骶骨裂孔連線外 1/3 處。",
                  indications: ["坐骨神經痛", "腰腿痠麻", "久坐不適"],
                  pressSeconds: 45,
                  bodyPoint: .init(side: .back, x: 0.56, y: 0.55))
        ]
    }

    private static func seedVitals() -> [VitalSnapshot] {
        let cal = Calendar.current
        var rng = SeededRandom(seed: 20260531)
        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            return VitalSnapshot(
                date: date,
                hrv: Double(38 + rng.next(0...22)),
                sleepScore: 62 + rng.next(0...28),
                spo2: 96 + Double(rng.next(0...3)),
                restingHR: 58 + rng.next(0...8)
            )
        }
    }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next(_ range: ClosedRange<Int>) -> Int {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(state % span)
    }
}
