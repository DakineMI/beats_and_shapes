import AppKit
import CoreGraphics

let size: CGFloat = 1024
let rect = CGRect(x: 0, y: 0, width: size, height: size)
let image = NSImage(size: rect.size)

image.lockFocus()
let context = NSGraphicsContext.current!.cgContext

// Background - Rounded Rect (macOS style)
let cornerRadius = size * 0.223 
let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
context.addPath(path)
context.clip()

context.setFillColor(NSColor.black.cgColor)
context.fill(rect)

// Drawing the "Braxton" Character (Based on the photo)
context.setStrokeColor(NSColor.cyan.cgColor)
context.setLineWidth(14)
context.setLineCap(.round)

let centerX = size / 2
let centerY = size / 2 + 30

// Face Outline - a bit more realistic jawline
context.move(to: CGPoint(x: centerX - 180, y: centerY + 180))
context.addCurve(to: CGPoint(x: centerX + 180, y: centerY + 180), 
                control1: CGPoint(x: centerX - 220, y: centerY - 250), 
                control2: CGPoint(x: centerX + 220, y: centerY - 250))
context.strokePath()

// Ears - closer to head
context.addEllipse(in: CGRect(x: centerX - 230, y: centerY - 30, width: 50, height: 90))
context.addEllipse(in: CGRect(x: centerX + 180, y: centerY - 30, width: 50, height: 90))
context.strokePath()

// Hair - Short side-swept spikes as seen in photo
context.setLineWidth(16)
context.move(to: CGPoint(x: centerX - 180, y: centerY + 180))
context.addLine(to: CGPoint(x: centerX - 160, y: centerY + 240))
context.addLine(to: CGPoint(x: centerX - 100, y: centerY + 250))
context.addLine(to: CGPoint(x: centerX - 40, y: centerY + 280))
context.addLine(to: CGPoint(x: centerX + 30, y: centerY + 260))
context.addLine(to: CGPoint(x: centerX + 100, y: centerY + 270))
context.addLine(to: CGPoint(x: centerX + 180, y: centerY + 180))
context.strokePath()

// Eyes - Twinkle & Grin
context.setLineWidth(12)
let leftEye = CGRect(x: centerX - 100, y: centerY + 40, width: 60, height: 70)
let rightEye = CGRect(x: centerX + 40, y: centerY + 40, width: 60, height: 70)
context.addEllipse(in: leftEye)
context.addEllipse(in: rightEye)
context.strokePath()

// The "Braxton" Twinkle
func drawTwinkle(at center: CGPoint, size: CGFloat) {
    for i in 0..<4 {
        let angle = CGFloat(i) * .pi / 2
        context.move(to: CGPoint(x: center.x - cos(angle) * size, y: center.y - sin(angle) * size))
        context.addLine(to: CGPoint(x: center.x + cos(angle) * size, y: center.y + sin(angle) * size))
    }
    context.strokePath()
}
drawTwinkle(at: CGPoint(x: centerX - 70, y: centerY + 75), size: 18)
drawTwinkle(at: CGPoint(x: centerX + 70, y: centerY + 75), size: 18)

// Wide grin - inspired by the photo's energy
context.move(to: CGPoint(x: centerX - 120, y: centerY - 100))
context.addQuadCurve(to: CGPoint(x: centerX + 120, y: centerY - 100), control: CGPoint(x: centerX, y: centerY - 280))
context.strokePath()

// Nose - simple curve
context.move(to: CGPoint(x: centerX - 15, y: centerY - 20))
context.addQuadCurve(to: CGPoint(x: centerX + 15, y: centerY - 20), control: CGPoint(x: centerX, y: centerY - 45))
context.strokePath()

// Glow effect
context.setShadow(offset: .zero, blur: 30, color: NSColor.cyan.cgColor)
context.move(to: CGPoint(x: centerX - 180, y: centerY + 180))
context.addCurve(to: CGPoint(x: centerX + 180, y: centerY + 180), 
                control1: CGPoint(x: centerX - 220, y: centerY - 250), 
                control2: CGPoint(x: centerX + 220, y: centerY - 250))
context.strokePath()

image.unlockFocus()

if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
    let png = bitmap.representation(using: .png, properties: [:])
    try? png?.write(to: URL(fileURLWithPath: "AppIcon.png"))
}
