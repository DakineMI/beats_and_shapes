import AppKit
import CoreGraphics

let width = 1024
let height = 768
let fps = 30
let totalFrames = 3 * fps
let outputDir = "frames"

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

func renderFrame(frameIndex: Int) {
    let t = Double(frameIndex) / Double(fps)
    let size = CGSize(width: width, height: height)
    let rect = CGRect(origin: .zero, size: size)
    let image = NSImage(size: size)
    
    image.lockFocus()
    let context = NSGraphicsContext.current!.cgContext
    
    // Solid Black Background
    context.setFillColor(NSColor.black.cgColor)
    context.fill(rect)
    
    // Pulse Logic
    let pulse = 1.0 + 0.03 * sin(2 * .pi * t / 1.5)
    context.translateBy(x: CGFloat(width)/2, y: CGFloat(height)/2)
    context.scaleBy(x: CGFloat(pulse), y: CGFloat(pulse))
    context.translateBy(x: -CGFloat(width)/2, y: -CGFloat(height)/2)
    
    // Draw BadMadBrax (Cyan)
    let font = NSFont(name: "AvenirNext-Heavy", size: 140) ?? NSFont.systemFont(ofSize: 140)
    let text = "BadMadBrax"
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.cyan
    ]
    let textSize = text.size(withAttributes: attributes)
    let textRect = CGRect(x: (CGFloat(width) - textSize.width) / 2, y: CGFloat(height) / 2 - 20, width: textSize.width, height: textSize.height)
    
    // Add Sawblade "Cuts" to letters (simulated with clipping paths)
    context.saveGState()
    text.draw(in: textRect, withAttributes: attributes)
    context.restoreGState()
    
    // Draw Outline Rect (Pink)
    let boxWidth: CGFloat = textSize.width + 40
    let boxHeight: CGFloat = 80
    let boxRect = CGRect(x: (CGFloat(width) - boxWidth) / 2, y: textRect.minY - 100, width: boxWidth, height: boxHeight)
    
    context.setStrokeColor(NSColor(red: 1.0, green: 0.1, blue: 0.5, alpha: 1.0).cgColor)
    context.setLineWidth(4)
    context.stroke(boxRect)
    
    // Draw GAMES (Pink)
    let gameFont = NSFont(name: "AvenirNext-Bold", size: 50) ?? NSFont.systemFont(ofSize: 50)
    let gameText = "GAMES"
    let gameAttributes: [NSAttributedString.Key: Any] = [
        .font: gameFont,
        .foregroundColor: NSColor(red: 1.0, green: 0.1, blue: 0.5, alpha: 1.0),
        .kern: 15 // Squat and elongated feel
    ]
    let gameTextSize = gameText.size(withAttributes: gameAttributes)
    let gameTextRect = CGRect(x: (CGFloat(width) - gameTextSize.width) / 2, y: boxRect.midY - 25, width: gameTextSize.width, height: gameTextSize.height)
    gameText.draw(in: gameTextRect, withAttributes: gameAttributes)
    
    // Add Glow (Layered)
    context.setShadow(offset: .zero, blur: 20 * CGFloat(pulse), color: NSColor.cyan.cgColor)
    
    image.unlockFocus()
    
    if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
        let png = bitmap.representation(using: .png, properties: [:])
        let fileName = String(format: "%03d.png", frameIndex)
        try? png?.write(to: URL(fileURLWithPath: "\(outputDir)/\(fileName)"))
    }
}

print("Rendering frames...")
for i in 0..<totalFrames {
    renderFrame(frameIndex: i)
    if i % 10 == 0 { print("Frame \(i)/\(totalFrames)") }
}
print("Done!")
