import SwiftUI

struct GraphView: View {
    @EnvironmentObject var identity: NodeIdentity

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size * 0.35
            let positions = layout(center: center, radius: radius)

            ZStack {
                edgeLayer(positions: positions)
                ForEach(identity.availableNodes) { node in
                    nodeMarker(node)
                        .position(positions[node.id] ?? center)
                }
            }
        }
        .frame(height: 220)
    }

    private func layout(center: CGPoint, radius: CGFloat) -> [String: CGPoint] {
        var result: [String: CGPoint] = [:]
        let nodes = identity.availableNodes
        guard !nodes.isEmpty else { return result }
        let step = (2 * .pi) / Double(nodes.count)
        for (i, node) in nodes.enumerated() {
            let angle = step * Double(i) - .pi / 2
            result[node.id] = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
        }
        return result
    }

    private func edgeLayer(positions: [String: CGPoint]) -> some View {
        Canvas { ctx, _ in
            for edge in identity.edges {
                guard let from = positions[edge.from],
                      let to = positions[edge.to]
                else { continue }

                let trimmed = trimLine(from: from, to: to, nodeRadius: 16, sideOffset: 4)
                var path = Path()
                path.move(to: trimmed.start)
                path.addLine(to: trimmed.end)

                let arrow = arrowHead(at: trimmed.end, from: trimmed.start, size: 6)

                let color: GraphicsContext.Shading
                let style: StrokeStyle
                switch edge.type {
                case .exact:
                    color = .color(Color.tInk.opacity(0.75))
                    style = StrokeStyle(lineWidth: 1.2)
                case .summary:
                    color = .color(Color.tSignal)
                    style = StrokeStyle(lineWidth: 1.2, dash: [4, 3])
                }
                ctx.stroke(path, with: color, style: style)
                ctx.fill(arrow, with: color)
            }
        }
    }

    private func trimLine(from: CGPoint, to: CGPoint, nodeRadius: CGFloat, sideOffset: CGFloat) -> (start: CGPoint, end: CGPoint) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = max(0.0001, sqrt(dx * dx + dy * dy))
        let ux = dx / len
        let uy = dy / len
        let px = -uy
        let py = ux
        let start = CGPoint(
            x: from.x + ux * nodeRadius + px * sideOffset,
            y: from.y + uy * nodeRadius + py * sideOffset
        )
        let end = CGPoint(
            x: to.x - ux * nodeRadius + px * sideOffset,
            y: to.y - uy * nodeRadius + py * sideOffset
        )
        return (start, end)
    }

    private func arrowHead(at tip: CGPoint, from origin: CGPoint, size: CGFloat) -> Path {
        let dx = tip.x - origin.x
        let dy = tip.y - origin.y
        let len = max(0.0001, sqrt(dx * dx + dy * dy))
        let ux = dx / len
        let uy = dy / len
        let leftX = tip.x - ux * size - uy * size * 0.6
        let leftY = tip.y - uy * size + ux * size * 0.6
        let rightX = tip.x - ux * size + uy * size * 0.6
        let rightY = tip.y - uy * size - ux * size * 0.6
        var p = Path()
        p.move(to: tip)
        p.addLine(to: CGPoint(x: leftX, y: leftY))
        p.addLine(to: CGPoint(x: rightX, y: rightY))
        p.closeSubpath()
        return p
    }

    @ViewBuilder
    private func nodeMarker(_ node: GraphNode) -> some View {
        let isSelf = node.id == identity.nodeID
        ZStack {
            Circle()
                .fill(isSelf ? Color.tOD : Color.tSurface2)
                .frame(width: 32, height: 32)
            Circle()
                .strokeBorder(isSelf ? Color.tKhaki : Color.tODDim, lineWidth: 1.5)
                .frame(width: 32, height: 32)
            Text(node.id)
                .font(.footnote.monospaced().bold())
                .foregroundStyle(isSelf ? Color.tInk : Color.tInkDim)
        }
    }
}

struct GraphLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            legendItem(label: "EXACT", color: Color.tInk, dashed: false)
            legendItem(label: "PARAPHRASED", color: Color.tSignal, dashed: true)
        }
        .font(.caption2.monospaced())
        .tracking(1.5)
    }

    private func legendItem(label: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Canvas { ctx, size in
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                let style = dashed
                    ? StrokeStyle(lineWidth: 1.2, dash: [4, 3])
                    : StrokeStyle(lineWidth: 1.2)
                ctx.stroke(path, with: .color(color), style: style)
            }
            .frame(width: 24, height: 8)
            Text(label).foregroundStyle(Color.tMuted)
        }
    }
}
