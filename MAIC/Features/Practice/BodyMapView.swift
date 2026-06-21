import SwiftUI

struct BodyMapView: View {
    let side: BodyPoint.Side
    let points: [Acupoint]
    let highlighted: Acupoint?

    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                BodySilhouette(side: side)
                    .fill(Color.secondary.opacity(0.06))
                BodySilhouette(side: side)
                    .stroke(Color.secondary.opacity(0.45), lineWidth: 1.5)

                ForEach(points.filter { $0.bodyPoint.side == side }) { a in
                    let isOn = a.id == highlighted?.id
                    Circle()
                        .fill(Theme.brandGradient)
                        .frame(width: isOn ? 18 : 9, height: isOn ? 18 : 9)
                        .overlay(
                            Circle().stroke(.white.opacity(0.85), lineWidth: isOn ? 2 : 1)
                        )
                        .shadow(color: Color.accentColor.opacity(isOn ? 0.8 : 0.2),
                                radius: isOn ? 14 : 3)
                        .scaleEffect(isOn && pulse ? 1.15 : 1.0)
                        .position(x: a.bodyPoint.x * geo.size.width,
                                  y: a.bodyPoint.y * geo.size.height)
                        .animation(.easeInOut(duration: 0.4), value: highlighted?.id)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}

private struct BodySilhouette: Shape {
    let side: BodyPoint.Side

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // head
        p.addEllipse(in: CGRect(x: w * 0.40, y: h * 0.01,
                                width: w * 0.20, height: h * 0.13))
        // neck
        p.addRect(CGRect(x: w * 0.46, y: h * 0.13,
                         width: w * 0.08, height: h * 0.05))
        // torso
        p.addRoundedRect(in: CGRect(x: w * 0.30, y: h * 0.18,
                                    width: w * 0.40, height: h * 0.32),
                         cornerSize: CGSize(width: 24, height: 24))
        // arms
        p.addRoundedRect(in: CGRect(x: w * 0.13, y: h * 0.20,
                                    width: w * 0.13, height: h * 0.36),
                         cornerSize: CGSize(width: 14, height: 14))
        p.addRoundedRect(in: CGRect(x: w * 0.74, y: h * 0.20,
                                    width: w * 0.13, height: h * 0.36),
                         cornerSize: CGSize(width: 14, height: 14))
        // legs
        p.addRoundedRect(in: CGRect(x: w * 0.32, y: h * 0.50,
                                    width: w * 0.16, height: h * 0.48),
                         cornerSize: CGSize(width: 16, height: 16))
        p.addRoundedRect(in: CGRect(x: w * 0.52, y: h * 0.50,
                                    width: w * 0.16, height: h * 0.48),
                         cornerSize: CGSize(width: 16, height: 16))
        return p
    }
}
