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
        HStack(spacing: 0) {
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
        guard let resetsAt = poller.menuBarLimit?.bucket.resetsAtDate else { return nil }
        let remaining = Int(resetsAt.timeIntervalSinceNow)
        guard remaining > 0 else { return "0m" }
        let days = remaining / 86400
        let hours = (remaining % 86400) / 3600
        let minutes = (remaining % 3600) / 60
        // Weekly windows run for days, so drop minutes once days show.
        if days > 0 { return "\(days)d\(hours)h" }
        if hours > 0 { return "\(hours)h\(String(format: "%02d", minutes))m" }
        return "\(minutes)m"
    }

    private func startTickTimer() {
        currentWindowProgress = poller.menuBarLimit?.windowProgress
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                currentWindowProgress = poller.menuBarLimit?.windowProgress
            }
        }
    }

    private func stopTickTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func usageColor(for limit: UsageLimit, windowProgress: Double) -> NSColor {
        switch limit.level(windowProgress: windowProgress) {
        case .normal: return .systemGreen
        case .warning: return .systemOrange
        case .critical: return .systemRed
        }
    }

    /// Renders the Claude logo + usage bar as a single NSImage
    private func renderCombinedImage() -> NSImage {
        let scale: CGFloat = 2
        let trailingPad: CGFloat = 4
        let totalWidth = logoSize + gap + barWidth + trailingPad
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

        // --- Draw usage bar (always visible; empty when no data) ---
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

        // Outline
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.3).cgColor)
        ctx.setLineWidth(1 * scale)
        ctx.addPath(trackPath)
        ctx.strokePath()

        // Fill, color, and tick all come from one limit so they always agree.
        if let limit = poller.menuBarLimit {
            let progress = currentWindowProgress ?? limit.windowProgress

            // Usage fill
            let fraction = limit.bucket.fraction
            if fraction > 0 {
                let fillWidth = bw * CGFloat(min(fraction, 1.0))
                let fillRect = CGRect(x: 0, y: 0, width: fillWidth, height: bh)
                ctx.saveGState()
                ctx.addPath(trackPath)
                ctx.clip()
                ctx.setFillColor(usageColor(for: limit, windowProgress: progress).cgColor)
                ctx.fill(fillRect)
                ctx.restoreGState()
            }

            // Tick marker for time position
            if progress > 0 && progress < 1 {
                let tickX = bw * CGFloat(progress)
                let tickWidth: CGFloat = 2 * scale
                ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
                ctx.fill(CGRect(x: tickX - tickWidth / 2, y: 0, width: tickWidth, height: bh))
            }
        }

        ctx.restoreGState()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

}
