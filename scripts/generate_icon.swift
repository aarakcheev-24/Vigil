import AppKit

// Минималистичная иконка Vigil: тёмный «squircle» + белый глаз-контур (страж).
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let S = CGFloat(size)
ctx.clear(CGRect(x: 0, y: 0, width: S, height: S))

// Фон-плашка с отступом (сетка иконок macOS) и скруглением.
let inset: CGFloat = 100
let rect = CGRect(x: inset, y: inset, width: S - inset*2, height: S - inset*2)
let radius = rect.width * 0.2237
let bg = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(bg)
ctx.clip()

// Вертикальный градиент: глубокий синий → почти чёрный.
let colors = [CGColor(red: 0.13, green: 0.20, blue: 0.38, alpha: 1),
              CGColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1)] as CFArray
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
ctx.resetClip()

// Глаз: миндалевидный контур + зрачок. Чистый белый.
let cx = S/2, cy = S/2
let halfW: CGFloat = 215, lid: CGFloat = 132
let eye = CGMutablePath()
eye.move(to: CGPoint(x: cx - halfW, y: cy))
eye.addQuadCurve(to: CGPoint(x: cx + halfW, y: cy), control: CGPoint(x: cx, y: cy + lid))
eye.addQuadCurve(to: CGPoint(x: cx - halfW, y: cy), control: CGPoint(x: cx, y: cy - lid))
ctx.setStrokeColor(.white)
ctx.setLineWidth(38)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.addPath(eye)
ctx.strokePath()

// Зрачок.
ctx.setFillColor(.white)
ctx.addEllipse(in: CGRect(x: cx - 74, y: cy - 74, width: 148, height: 148))
ctx.fillPath()

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
