// Zeichnet das App-Symbol (1024x1024) – laeuft auf dem macOS-Runner vor dem Build.
// Aufruf: swift scripts/make_icon.swift <ziel.png>
import AppKit

let size = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(deviceRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
}
func fill(_ c: NSColor, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
    c.setFill(); NSBezierPath(rect: NSRect(x: x, y: y, width: w, height: h)).fill()
}
// Koordinaten: Ursprung unten links
let S = CGFloat(size)
// Hintergrund: Desktop-Tuerkis
fill(rgb(0, 128, 128), 0, 0, S, S)
// Fenster mit 3D-Rand
let wx: CGFloat = 96, wy: CGFloat = 120, ww: CGFloat = 832, wh: CGFloat = 780
fill(rgb(0, 0, 0), wx, wy, ww, wh)
fill(rgb(255, 255, 255), wx, wy + 8, ww - 8, wh - 8)
fill(rgb(128, 128, 128), wx + 8, wy + 8, ww - 16, wh - 16)
fill(rgb(192, 192, 192), wx + 8, wy + 16, ww - 24, wh - 24)
// Titelleiste mit Verlauf
let tx = wx + 16, ty = wy + wh - 96, tw = ww - 40, th: CGFloat = 72
if let grad = NSGradient(starting: rgb(0, 0, 128), ending: rgb(16, 132, 208)) {
    grad.draw(in: NSRect(x: tx, y: ty, width: tw, height: th), angle: 0)
}
// zwei weisse Dateifenster
let py = wy + 150, ph = ty - py - 24, pw = (tw - 24) / 2
for i in 0..<2 {
    let px = tx + CGFloat(i) * (pw + 24)
    fill(rgb(128, 128, 128), px, py, pw, ph)
    fill(rgb(255, 255, 255), px + 6, py, pw - 6, ph - 6)
    // Zeilen
    var ly = py + ph - 70
    var row = 0
    while ly > py + 30 {
        let isFolder = row < 2
        if row == 2 && i == 0 { fill(rgb(0, 0, 128), px + 14, ly - 8, pw - 28, 44) }
        if isFolder {
            fill(rgb(255, 210, 74), px + 26, ly, 46, 30)
            fill(rgb(255, 210, 74), px + 26, ly + 26, 22, 8)
        } else {
            fill(row == 2 && i == 0 ? rgb(255, 255, 255) : rgb(160, 160, 160), px + 30, ly, 34, 30)
        }
        let textColor = (row == 2 && i == 0) ? rgb(255, 255, 255) : (row == 3 && i == 1 ? rgb(255, 0, 0) : rgb(0, 0, 0))
        fill(textColor, px + 90, ly + 8, pw - 150 - CGFloat((row * 37) % 90), 14)
        ly -= 62
        row += 1
    }
}
// Funktionstastenleiste
for i in 0..<4 {
    let bw = (tw - 30) / 4
    let bx = tx + CGFloat(i) * (bw + 10)
    fill(rgb(255, 255, 255), bx, wy + 40, bw, 80)
    fill(rgb(64, 64, 64), bx + 6, wy + 40, bw - 6, 74)
    fill(rgb(192, 192, 192), bx + 6, wy + 46, bw - 12, 68)
    fill(rgb(0, 0, 0), bx + 26, wy + 72, bw - 52, 14)
}
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: out))
print("Symbol geschrieben: \(out)")
