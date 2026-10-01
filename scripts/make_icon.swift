import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let size = NSSize(width: 1024, height: 1024)
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
NSColor(srgbRed: 0.035, green: 0.045, blue: 0.065, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()
for index in 0..<6 {
    let inset = CGFloat(120 + index * 47)
    let oval = NSBezierPath(ovalIn: NSRect(x: inset, y: inset, width: 1024 - 2 * inset, height: 1024 - 2 * inset))
    NSColor(srgbRed: 0.77, green: 0.89, blue: 0.81, alpha: 0.16 + Double(index) * 0.075).setStroke()
    oval.lineWidth = 2
    oval.stroke()
}
let text = "f" as NSString
let font = NSFont(name: "NewYork-Regular", size: 390) ?? NSFont.systemFont(ofSize: 390, weight: .ultraLight)
let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(srgbRed: 0.77, green: 0.89, blue: 0.81, alpha: 1)]
let textSize = text.size(withAttributes: attributes)
text.draw(at: NSPoint(x: (1024 - textSize.width) / 2, y: (1024 - textSize.height) / 2 + 16), withAttributes: attributes)
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent("AppIcon.png"))
try """
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"flow","version":1}}
""".write(to: destination.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
