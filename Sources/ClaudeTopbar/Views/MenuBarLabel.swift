import SwiftUI
import AppKit

struct MenuBarLabel: View {
    let poller: UsagePoller
    @State private var tickTimer: Timer?
    @State private var currentWindowProgress: Double = 0

    private let logoSize: CGFloat = 14
    private let barWidth: CGFloat = 40
    private let barHeight: CGFloat = 8
    private let gap: CGFloat = 4
    private let cornerRadius: CGFloat = 2

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: renderCombinedImage())
                .renderingMode(.original)
            if poller.usage != nil {
                Text(timeRemainingLabel)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
            } else if poller.error != nil {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11))
            } else {
                Text("--")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
            }
        }
        .onAppear { startTickTimer() }
        .onDisappear { stopTickTimer() }
    }

    private var timeRemainingLabel: String {
        guard let resetsAt = poller.sessionResetsAt else { return "--" }
        let remaining = resetsAt.timeIntervalSinceNow
        guard remaining > 0 else { return "0m" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", minutes))m"
        }
        return "\(minutes)m"
    }

    private func startTickTimer() {
        currentWindowProgress = poller.windowProgress
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                currentWindowProgress = poller.windowProgress
            }
        }
    }

    private func stopTickTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func usageColor(fraction: Double, percentage: Int) -> NSColor {
        if percentage >= 95 { return .systemRed }
        if percentage >= 80 { return .systemOrange }
        if fraction < currentWindowProgress { return .systemGreen }
        return .systemOrange
    }

    /// Renders the Claude logo + usage bar as a single NSImage
    private func renderCombinedImage() -> NSImage {
        let scale: CGFloat = 2
        let totalWidth = logoSize + gap + barWidth
        let totalHeight = logoSize
        let pw = totalWidth * scale
        let ph = totalHeight * scale

        let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
        image.addRepresentation(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(pw), pixelsHigh: Int(ph),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!)

        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        ctx.scaleBy(x: 1 / scale, y: 1 / scale)

        // --- Draw Claude logo ---
        ctx.saveGState()
        // Flip Y for SVG
        ctx.translateBy(x: 0, y: logoSize * scale)
        ctx.scaleBy(x: 1, y: -1)
        let logoScale = (logoSize * scale) / 24.0
        ctx.scaleBy(x: logoScale, y: logoScale)

        let claudeColor = NSColor(red: 0xD9/255.0, green: 0x77/255.0, blue: 0x57/255.0, alpha: 1.0)
        ctx.setFillColor(claudeColor.cgColor)
        ctx.addPath(claudeLogoPath())
        ctx.fillPath()
        ctx.restoreGState()

        // --- Draw usage bar ---
        let barX = (logoSize + gap) * scale
        let bw = barWidth * scale
        let bh = barHeight * scale
        let barY = (totalHeight - barHeight) / 2 * scale  // vertically center
        let cr = cornerRadius * scale

        ctx.saveGState()
        ctx.translateBy(x: barX, y: barY)

        // Track background
        let trackRect = CGRect(x: 0, y: 0, width: bw, height: bh)
        let trackPath = CGPath(roundedRect: trackRect, cornerWidth: cr, cornerHeight: cr, transform: nil)
        ctx.setFillColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
        ctx.addPath(trackPath)
        ctx.fillPath()

        // Usage fill
        let fraction = poller.sessionFraction
        if fraction > 0 {
            let fillWidth = bw * CGFloat(min(fraction, 1.0))
            let fillRect = CGRect(x: 0, y: 0, width: fillWidth, height: bh)
            ctx.saveGState()
            ctx.addPath(trackPath)
            ctx.clip()
            ctx.setFillColor(usageColor(fraction: fraction, percentage: poller.displayPercentage).cgColor)
            ctx.fill(fillRect)
            ctx.restoreGState()
        }

        // Tick marker for time position
        let progress = currentWindowProgress
        if progress > 0 && progress < 1 {
            let tickX = bw * CGFloat(progress)
            let tickWidth: CGFloat = 2 * scale
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            ctx.fill(CGRect(x: tickX - tickWidth / 2, y: 0, width: tickWidth, height: bh))
        }

        ctx.restoreGState()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func claudeLogoPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 4.7144, y: 15.9555))
        path.addLine(to: CGPoint(x: 9.4318, y: 13.3084))
        path.addLine(to: CGPoint(x: 9.5108, y: 13.0777))
        path.addLine(to: CGPoint(x: 9.4318, y: 12.9502))
        path.addLine(to: CGPoint(x: 9.2011, y: 12.9502))
        path.addLine(to: CGPoint(x: 8.4118, y: 12.9016))
        path.addLine(to: CGPoint(x: 5.7162, y: 12.8287))
        path.addLine(to: CGPoint(x: 3.3787, y: 12.7316))
        path.addLine(to: CGPoint(x: 1.1141, y: 12.6102))
        path.addLine(to: CGPoint(x: 0.5434, y: 12.4887))
        path.addLine(to: CGPoint(x: 0.0091, y: 11.7845))
        path.addLine(to: CGPoint(x: 0.0637, y: 11.4323))
        path.addLine(to: CGPoint(x: 0.5434, y: 11.1105))
        path.addLine(to: CGPoint(x: 1.2294, y: 11.1713))
        path.addLine(to: CGPoint(x: 2.7473, y: 11.2745))
        path.addLine(to: CGPoint(x: 5.024, y: 11.4323))
        path.addLine(to: CGPoint(x: 6.6754, y: 11.5295))
        path.addLine(to: CGPoint(x: 9.1222, y: 11.7845))
        path.addLine(to: CGPoint(x: 9.5108, y: 11.7845))
        path.addLine(to: CGPoint(x: 9.5654, y: 11.6266))
        path.addLine(to: CGPoint(x: 9.4318, y: 11.5295))
        path.addLine(to: CGPoint(x: 9.3286, y: 11.4323))
        path.addLine(to: CGPoint(x: 6.973, y: 9.8356))
        path.addLine(to: CGPoint(x: 4.423, y: 8.1477))
        path.addLine(to: CGPoint(x: 3.0874, y: 7.1763))
        path.addLine(to: CGPoint(x: 2.3649, y: 6.6845))
        path.addLine(to: CGPoint(x: 2.0006, y: 6.2231))
        path.addLine(to: CGPoint(x: 1.8428, y: 5.2153))
        path.addLine(to: CGPoint(x: 2.4985, y: 4.4928))
        path.addLine(to: CGPoint(x: 3.3788, y: 4.5535))
        path.addLine(to: CGPoint(x: 3.6034, y: 4.6142))
        path.addLine(to: CGPoint(x: 4.4959, y: 5.3002))
        path.addLine(to: CGPoint(x: 6.4023, y: 6.7756))
        path.addLine(to: CGPoint(x: 8.8916, y: 8.6092))
        path.addLine(to: CGPoint(x: 9.2559, y: 8.9127))
        path.addLine(to: CGPoint(x: 9.4016, y: 8.8095))
        path.addLine(to: CGPoint(x: 9.4198, y: 8.7367))
        path.addLine(to: CGPoint(x: 9.2558, y: 8.4634))
        path.addLine(to: CGPoint(x: 7.9019, y: 6.0167))
        path.addLine(to: CGPoint(x: 6.4569, y: 3.5274))
        path.addLine(to: CGPoint(x: 5.8134, y: 2.4954))
        path.addLine(to: CGPoint(x: 5.6434, y: 1.876))
        path.addLine(to: CGPoint(x: 5.5402, y: 1.1475))
        path.addLine(to: CGPoint(x: 6.287, y: 0.1335))
        path.addLine(to: CGPoint(x: 6.6997, y: 0))
        path.addLine(to: CGPoint(x: 7.6954, y: 0.1336))
        path.addLine(to: CGPoint(x: 8.1144, y: 0.4978))
        path.addLine(to: CGPoint(x: 8.7336, y: 1.9125))
        path.addLine(to: CGPoint(x: 9.7354, y: 4.1407))
        path.addLine(to: CGPoint(x: 11.2897, y: 7.1703))
        path.addLine(to: CGPoint(x: 11.745, y: 8.0688))
        path.addLine(to: CGPoint(x: 11.9879, y: 8.9006))
        path.addLine(to: CGPoint(x: 12.0789, y: 9.1556))
        path.addLine(to: CGPoint(x: 12.2368, y: 9.1556))
        path.addLine(to: CGPoint(x: 12.2368, y: 9.0099))
        path.addLine(to: CGPoint(x: 12.3643, y: 7.3039))
        path.addLine(to: CGPoint(x: 12.6011, y: 5.2092))
        path.addLine(to: CGPoint(x: 12.8318, y: 2.5135))
        path.addLine(to: CGPoint(x: 12.9107, y: 1.7546))
        path.addLine(to: CGPoint(x: 13.2871, y: 0.8439))
        path.addLine(to: CGPoint(x: 14.0339, y: 0.3521))
        path.addLine(to: CGPoint(x: 14.6167, y: 0.6314))
        path.addLine(to: CGPoint(x: 15.0964, y: 1.3174))
        path.addLine(to: CGPoint(x: 15.0296, y: 1.7607))
        path.addLine(to: CGPoint(x: 14.7443, y: 3.6124))
        path.addLine(to: CGPoint(x: 14.1857, y: 6.5145))
        path.addLine(to: CGPoint(x: 13.8214, y: 8.4574))
        path.addLine(to: CGPoint(x: 14.0339, y: 8.4574))
        path.addLine(to: CGPoint(x: 14.2768, y: 8.2145))
        path.addLine(to: CGPoint(x: 15.2603, y: 6.9092))
        path.addLine(to: CGPoint(x: 16.9117, y: 4.8449))
        path.addLine(to: CGPoint(x: 17.6403, y: 4.0253))
        path.addLine(to: CGPoint(x: 18.4903, y: 3.1207))
        path.addLine(to: CGPoint(x: 19.0367, y: 2.6896))
        path.addLine(to: CGPoint(x: 20.0688, y: 2.6896))
        path.addLine(to: CGPoint(x: 20.8278, y: 3.8189))
        path.addLine(to: CGPoint(x: 20.4878, y: 4.9846))
        path.addLine(to: CGPoint(x: 19.4253, y: 6.3324))
        path.addLine(to: CGPoint(x: 18.5449, y: 7.4738))
        path.addLine(to: CGPoint(x: 17.2821, y: 9.1738))
        path.addLine(to: CGPoint(x: 16.4928, y: 10.5338))
        path.addLine(to: CGPoint(x: 16.5657, y: 10.6431))
        path.addLine(to: CGPoint(x: 16.7539, y: 10.6248))
        path.addLine(to: CGPoint(x: 19.6074, y: 10.0178))
        path.addLine(to: CGPoint(x: 21.1495, y: 9.7384))
        path.addLine(to: CGPoint(x: 22.9891, y: 9.4227))
        path.addLine(to: CGPoint(x: 23.8209, y: 9.8113))
        path.addLine(to: CGPoint(x: 23.9119, y: 10.2059))
        path.addLine(to: CGPoint(x: 23.5841, y: 11.0134))
        path.addLine(to: CGPoint(x: 21.6171, y: 11.4991))
        path.addLine(to: CGPoint(x: 19.3099, y: 11.9605))
        path.addLine(to: CGPoint(x: 15.8735, y: 12.7741))
        path.addLine(to: CGPoint(x: 15.831, y: 12.8045))
        path.addLine(to: CGPoint(x: 15.8796, y: 12.8652))
        path.addLine(to: CGPoint(x: 17.4278, y: 13.0109))
        path.addLine(to: CGPoint(x: 18.0896, y: 13.0473))
        path.addLine(to: CGPoint(x: 19.7106, y: 13.0473))
        path.addLine(to: CGPoint(x: 22.7281, y: 13.272))
        path.addLine(to: CGPoint(x: 23.5173, y: 13.794))
        path.addLine(to: CGPoint(x: 23.9909, y: 14.4316))
        path.addLine(to: CGPoint(x: 23.9119, y: 14.9173))
        path.addLine(to: CGPoint(x: 22.6977, y: 15.5366))
        path.addLine(to: CGPoint(x: 21.0584, y: 15.148))
        path.addLine(to: CGPoint(x: 17.2334, y: 14.2373))
        path.addLine(to: CGPoint(x: 15.9221, y: 13.9094))
        path.addLine(to: CGPoint(x: 15.7399, y: 13.9094))
        path.addLine(to: CGPoint(x: 15.7399, y: 14.0187))
        path.addLine(to: CGPoint(x: 16.8328, y: 15.0873))
        path.addLine(to: CGPoint(x: 18.8363, y: 16.8965))
        path.addLine(to: CGPoint(x: 21.3438, y: 19.2279))
        path.addLine(to: CGPoint(x: 21.4713, y: 19.8047))
        path.addLine(to: CGPoint(x: 21.1495, y: 20.2601))
        path.addLine(to: CGPoint(x: 20.8095, y: 20.2115))
        path.addLine(to: CGPoint(x: 18.6056, y: 18.554))
        path.addLine(to: CGPoint(x: 17.7556, y: 17.8072))
        path.addLine(to: CGPoint(x: 15.831, y: 16.1862))
        path.addLine(to: CGPoint(x: 15.7035, y: 16.1862))
        path.addLine(to: CGPoint(x: 15.7035, y: 16.3562))
        path.addLine(to: CGPoint(x: 16.1467, y: 17.0058))
        path.addLine(to: CGPoint(x: 18.4903, y: 20.5272))
        path.addLine(to: CGPoint(x: 18.6117, y: 21.6079))
        path.addLine(to: CGPoint(x: 18.4417, y: 21.96))
        path.addLine(to: CGPoint(x: 17.8346, y: 22.1725))
        path.addLine(to: CGPoint(x: 17.1667, y: 22.0511))
        path.addLine(to: CGPoint(x: 15.7946, y: 20.1265))
        path.addLine(to: CGPoint(x: 14.38, y: 17.959))
        path.addLine(to: CGPoint(x: 13.2386, y: 16.0162))
        path.addLine(to: CGPoint(x: 13.0989, y: 16.0952))
        path.addLine(to: CGPoint(x: 12.4249, y: 23.3504))
        path.addLine(to: CGPoint(x: 12.1093, y: 23.7207))
        path.addLine(to: CGPoint(x: 11.3807, y: 24))
        path.addLine(to: CGPoint(x: 10.7736, y: 23.5386))
        path.addLine(to: CGPoint(x: 10.4518, y: 22.7918))
        path.addLine(to: CGPoint(x: 10.7736, y: 21.3165))
        path.addLine(to: CGPoint(x: 11.1622, y: 19.3919))
        path.addLine(to: CGPoint(x: 11.4779, y: 17.8619))
        path.addLine(to: CGPoint(x: 11.7632, y: 15.9615))
        path.addLine(to: CGPoint(x: 11.9332, y: 15.3301))
        path.addLine(to: CGPoint(x: 11.9211, y: 15.2876))
        path.addLine(to: CGPoint(x: 11.7814, y: 15.3058))
        path.addLine(to: CGPoint(x: 10.3486, y: 17.273))
        path.addLine(to: CGPoint(x: 8.169, y: 20.2176))
        path.addLine(to: CGPoint(x: 6.4447, y: 22.0632))
        path.addLine(to: CGPoint(x: 6.0319, y: 22.2272))
        path.addLine(to: CGPoint(x: 5.3155, y: 21.8568))
        path.addLine(to: CGPoint(x: 5.3823, y: 21.195))
        path.addLine(to: CGPoint(x: 5.7831, y: 20.6061))
        path.addLine(to: CGPoint(x: 8.1691, y: 17.5704))
        path.addLine(to: CGPoint(x: 9.608, y: 15.6884))
        path.addLine(to: CGPoint(x: 10.537, y: 14.6016))
        path.addLine(to: CGPoint(x: 10.5308, y: 14.4437))
        path.addLine(to: CGPoint(x: 10.4762, y: 14.4437))
        path.addLine(to: CGPoint(x: 4.1377, y: 18.5601))
        path.addLine(to: CGPoint(x: 3.0084, y: 18.7058))
        path.addLine(to: CGPoint(x: 2.5227, y: 18.2504))
        path.addLine(to: CGPoint(x: 2.5835, y: 17.5037))
        path.addLine(to: CGPoint(x: 2.8142, y: 17.2608))
        path.addLine(to: CGPoint(x: 4.7206, y: 15.9494))
        path.closeSubpath()
        return path
    }
}
