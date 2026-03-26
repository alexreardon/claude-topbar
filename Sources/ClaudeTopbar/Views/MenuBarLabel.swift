import SwiftUI
import AppKit

struct MenuBarLabel: View {
    let poller: UsagePoller
    @State private var tickTimer: Timer?
    @State private var currentWindowProgress: Double?

    private let logoSize: CGFloat = 14
    private let barWidth: CGFloat = 40
    private let barHeight: CGFloat = 8
    private let gap: CGFloat = 4
    private let cornerRadius: CGFloat = 2

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: renderCombinedImage())
                .renderingMode(.original)
            if poller.showTimeInMenuBar, poller.usage != nil, let label = timeRemainingLabel {
                Text(label)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
            }
        }
        .onAppear { startTickTimer() }
        .onDisappear { stopTickTimer() }
    }

    private var timeRemainingLabel: String? {
        guard let resetsAt = poller.sessionResetsAt else { return nil }
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
        if poller.usage != nil { currentWindowProgress = poller.windowProgress }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if poller.usage != nil { currentWindowProgress = poller.windowProgress }
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
        let wp = currentWindowProgress ?? poller.windowProgress
        if fraction < wp { return .systemGreen }
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

        ctx.setFillColor(NSColor(ClaudeLogo.terracotta).cgColor)
        ctx.addPath(ClaudeLogo.cgPath())
        ctx.fillPath()
        ctx.restoreGState()

        // --- Draw usage bar (only when data is available) ---
        if poller.usage != nil {
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
            let progress = currentWindowProgress ?? poller.windowProgress
            if progress > 0 && progress < 1 {
                let tickX = bw * CGFloat(progress)
                let tickWidth: CGFloat = 2 * scale
                ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
                ctx.fill(CGRect(x: tickX - tickWidth / 2, y: 0, width: tickWidth, height: bh))
            }

            ctx.restoreGState()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

}
