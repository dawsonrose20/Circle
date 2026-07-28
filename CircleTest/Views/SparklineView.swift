import SwiftUI

struct SparklineView: View {
    let points: [Double]
    let color: Color
    var width: CGFloat = 60
    var height: CGFloat = 28

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else { return }
            let minV = points.min() ?? 0
            let maxV = points.max() ?? 1
            let range = maxV - minV == 0 ? 1 : maxV - minV
            let step = size.width / CGFloat(points.count - 1)

            func pt(_ i: Int) -> CGPoint {
                CGPoint(
                    x: CGFloat(i) * step,
                    y: size.height - CGFloat((points[i] - minV) / range) * size.height
                )
            }

            // Fill path
            var fill = Path()
            fill.move(to: CGPoint(x: 0, y: size.height))
            for i in 0..<points.count {
                fill.addLine(to: pt(i))
            }
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.closeSubpath()
            context.fill(fill, with: .color(color.opacity(0.15)))

            // Line path
            var line = Path()
            line.move(to: pt(0))
            for i in 1..<points.count {
                line.addLine(to: pt(i))
            }
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .frame(width: width, height: height)
    }
}

#Preview {
    SparklineView(points: [0.2, 0.35, 0.3, 0.45, 0.5, 0.6, 0.7], color: Theme.green)
        .preferredColorScheme(.dark)
        .padding()
        .background(Theme.background)
}
