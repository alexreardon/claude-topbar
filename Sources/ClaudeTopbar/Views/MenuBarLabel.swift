import SwiftUI
import AppKit

struct MenuBarLabel: View {
    let poller: UsagePoller
    @State private var tickTimer: Timer?
    @State private var currentWindowProgress: Double = 0

    private let barWidth: CGFloat = 40
    private let barHeight: CGFloat = 8
    private let cornerRadius: CGFloat = 2

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: renderBarImage())
                .renderingMode(.original)
            if poller.usage != nil {
                Text("\(poller.displayPercentage)%")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
            } else if poller.error != nil {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11))
            } else {
                Text("--%")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
            }
        }
        .onAppear { startTickTimer() }
        .onDisappear { stopTickTimer() }
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

    private func usageColor(for percentage: Int) -> NSColor {
        if percentage >= 95 { return .systemRed }
        if percentage >= 80 { return .systemOrange }
        return .systemBlue
    }

    private func renderBarImage() -> NSImage {
        let scale: CGFloat = 2
        let w = barWidth * scale
        let h = barHeight * scale
        let cr = cornerRadius * scale

        let image = NSImage(size: NSSize(width: barWidth, height: barHeight))
        image.addRepresentation(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(w),
            pixelsHigh: Int(h),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!)

        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        ctx.scaleBy(x: 1 / scale, y: 1 / scale)

        // Track background
        let trackRect = CGRect(x: 0, y: 0, width: w, height: h)
        let trackPath = CGPath(roundedRect: trackRect, cornerWidth: cr, cornerHeight: cr, transform: nil)
        ctx.setFillColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
        ctx.addPath(trackPath)
        ctx.fillPath()

        // Usage fill
        let fraction = poller.sessionFraction
        if fraction > 0 {
            let fillWidth = w * CGFloat(min(fraction, 1.0))
            let fillRect = CGRect(x: 0, y: 0, width: fillWidth, height: h)
            ctx.saveGState()
            ctx.addPath(trackPath)
            ctx.clip()
            ctx.setFillColor(usageColor(for: poller.displayPercentage).cgColor)
            ctx.fill(fillRect)
            ctx.restoreGState()
        }

        // Tick marker for time position
        let progress = currentWindowProgress
        if progress > 0 && progress < 1 {
            let tickX = w * CGFloat(progress)
            let tickWidth: CGFloat = 2 * scale
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            ctx.fill(CGRect(x: tickX - tickWidth / 2, y: 0, width: tickWidth, height: h))
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
