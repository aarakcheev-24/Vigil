import AppKit

// Иконка Vigil: тёмный «squircle» + ТОТ ЖЕ глаз, что и в строке меню (SF Symbol eye.fill).
// Так иконка приложения и значок в меню-баре выглядят одинаково.
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let S = CGFloat(size)
ctx.clear(CGRect(x: 0, y: 0, width: S, height: S))

// Фон-плашка со скруглением (сетка иконок macOS).
let inset: CGFloat = 100
let rect = CGRect(x: inset, y: inset, width: S - inset*2, height: S - inset*2)
let radius = rect.width * 0.2237
let bg = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.saveGState()
ctx.addPath(bg); ctx.clip()
let colors = [CGColor(red: 0.13, green: 0.20, blue: 0.38, alpha: 1),
              CGColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1)] as CFArray
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

// Тот же символ-глаз, что и в строке меню, окрашенный в белый.
let cfg = NSImage.SymbolConfiguration(pointSize: 600, weight: .regular)
let sym = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: nil)!
    .withSymbolConfiguration(cfg)!
let white = NSImage(size: sym.size)
white.lockFocus()
NSColor.white.set()
let sr = NSRect(origin: .zero, size: sym.size)
sym.draw(in: sr)
sr.fill(using: .sourceAtop)
white.unlockFocus()

// Вписываем по ширине ~60% иконки, по центру.
let targetW = S * 0.60
let scale = targetW / sym.size.width
let w = sym.size.width * scale, h = sym.size.height * scale
white.draw(in: NSRect(x: (S - w)/2, y: (S - h)/2, width: w, height: h),
           from: .zero, operation: .sourceOver, fraction: 1.0)

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
