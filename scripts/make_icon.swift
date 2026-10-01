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
let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
    CGColor(red: 0.13, green: 0.20, blue: 0.19, alpha: 1),
    CGColor(red: 0.035, green: 0.045, blue: 0.065, alpha: 1)
] as CFArray, locations: [0, 1])!
context.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 512), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 512), endRadius: 560,
                           options: .drawsAfterEndLocation)

// Broad, evenly spaced rings remain distinct at home-screen sizes.
// The open center is the mark: a little space, with no letterform.
for index in 0..<5 {
    let inset = CGFloat(158 + index * 62)
    let oval = NSBezierPath(ovalIn: NSRect(x: inset, y: inset, width: 1024 - 2 * inset, height: 1024 - 2 * inset))
    NSColor(srgbRed: 0.77, green: 0.89, blue: 0.81, alpha: 0.30 + Double(index) * 0.16).setStroke()
    oval.lineWidth = 14
    oval.stroke()
}
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent("AppIcon.png"))
try """
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"flow","version":1}}
""".write(to: destination.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
