// App Store images for Math Race Kids.
// Usage: swiftc -parse-as-library -O tools/assets/main.swift -o /tmp/mr-assets && /tmp/mr-assets <raw-shots-dir> appstore
// Raw shots are captured from DEBUG builds on simulators (see tools/shots.sh).

import SwiftUI
import AppKit

let blue = Color(red: 0.20, green: 0.70, blue: 1.00)
let purple = Color(red: 0.55, green: 0.40, blue: 1.00)
let deep = Color(red: 0.16, green: 0.12, blue: 0.42)

struct Caption { let title: String; let subtitle: String }

let captions: [String: [String: Caption]] = [
    "single": ["en": .init(title: "Race the clock!", subtitle: "Pick the right answer as fast as you can"),
               "sk": .init(title: "Pretekaj s časom!", subtitle: "Vyber správnu odpoveď čo najrýchlejšie")],
    "duel": ["en": .init(title: "Duel on one phone", subtitle: "Whoever hits STOP first answers"),
             "sk": .init(title: "Duel na jednom telefóne", subtitle: "Kto prvý stlačí STOP, odpovedá")],
    "faceoff": ["en": .init(title: "Face to face", subtitle: "Two players, one screen split in half"),
                "sk": .init(title: "Tvárou v tvár", subtitle: "Dvaja hráči, displej rozdelený na polovice")],
    "settings": ["en": .init(title: "Practice your way", subtitle: "Tables up to 12, plus + − ÷ and mix"),
                 "sk": .init(title: "Precvičuj po svojom", subtitle: "Násobilka do 12, aj + − ÷ a mix")],
    "start": ["en": .init(title: "Made for kids", subtitle: "No ads · no tracking · parental gate"),
              "sk": .init(title: "Pre deti", subtitle: "Bez reklám · bez sledovania · rodičovská brána")],
]

func load(_ path: String) -> NSImage? { NSImage(contentsOfFile: path) }

struct Device: View {
    let image: NSImage
    let width: CGFloat
    var corner: CGFloat { width * 0.075 }
    var body: some View {
        let aspect = image.size.height / max(1, image.size.width)
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .frame(width: width, height: width * aspect)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .padding(width * 0.022)
            .background(RoundedRectangle(cornerRadius: corner * 1.25, style: .continuous).fill(Color(white: 0.08)))
            .shadow(color: .black.opacity(0.35), radius: width * 0.04, y: width * 0.02)
    }
}

struct Shot: View {
    let size: CGSize
    let caption: Caption
    let image: NSImage
    var body: some View {
        let fs = size.width / 1320
        let aspect = image.size.height / max(1, image.size.width)
        let top = size.height * 0.2
        let maxH = size.height - top - 90 * fs
        let devW = min(size.width * 0.82, maxH / (aspect * 1.05))
        ZStack(alignment: .top) {
            LinearGradient(colors: [blue, purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 0) {
                Text(caption.title)
                    .font(.system(size: 104 * fs, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6).lineLimit(1)
                    .padding(.top, size.height * 0.055)
                Text(caption.subtitle)
                    .font(.system(size: 50 * fs, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .opacity(0.9)
                    .padding(.top, 24 * fs)
                Spacer(minLength: 0)
                Device(image: image, width: devW)
                    .padding(.bottom, 70 * fs)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 70 * fs)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Product page header / search image: name + tagline + iPhone and iPad shots.
struct Banner: View {
    let size: CGSize
    let lang: String
    let phone: NSImage
    let pad: NSImage
    var body: some View {
        let h = min(size.height, size.width * 0.45)
        let tagline = lang == "sk" ? "Preteky v násobilke\npre deti" : "The times tables race\nfor kids"
        ZStack {
            LinearGradient(colors: [deep, purple, blue], startPoint: .leading, endPoint: .trailing)
            HStack(spacing: h * 0.12) {
                VStack(alignment: .leading, spacing: h * 0.045) {
                    Text("Math Race Kids")
                        .font(.system(size: h * 0.12, weight: .black, design: .rounded))
                        .fixedSize()
                    Text(tagline)
                        .font(.system(size: h * 0.07, weight: .bold, design: .rounded))
                        .opacity(0.9)
                        .fixedSize()
                    Text("+  −  ×  ÷")
                        .font(.system(size: h * 0.09, weight: .black, design: .rounded))
                        .opacity(0.75)
                }
                .foregroundStyle(.white)
                ZStack(alignment: .bottomLeading) {
                    Device(image: pad, width: h * 0.6)
                        .rotationEffect(.degrees(4))
                        .padding(.leading, h * 0.16)
                    Device(image: phone, width: h * 0.3)
                        .rotationEffect(.degrees(-6))
                        .offset(y: h * 0.06)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

@MainActor func save<V: View>(_ view: V, _ path: String, jpeg: Bool = true) {
    let r = ImageRenderer(content: view.environment(\.colorScheme, .light))
    r.scale = 1
    r.isOpaque = true
    guard let cg = r.cgImage else { print("FAIL", path); return }
    // Redraw into an RGB context without alpha (App Store rejects images with alpha).
    let ctx = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    let data = jpeg ? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!
                    : rep.representation(using: .png, properties: [:])!
    try! FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try! data.write(to: URL(fileURLWithPath: path))
    print("ok", path, cg.width, "x", cg.height)
}

@main struct Main {
    @MainActor static func main() {
        let raw = CommandLine.arguments[1]
        let out = CommandLine.arguments[2]
        let sets: [(prefix: String, folder: String, size: CGSize, order: [(String, String)])] = [
            ("iphone", "iphone-6.9", CGSize(width: 1320, height: 2868),
             [("01-single", "single"), ("02-duel", "duel"), ("03-settings", "settings"), ("04-start", "start")]),
            ("iphone", "iphone-medium-1206x2622", CGSize(width: 1206, height: 2622),
             [("01-single", "single"), ("02-duel", "duel"), ("03-settings", "settings"), ("04-start", "start")]),
            ("iphone", "iphone-medium-1179x2556", CGSize(width: 1179, height: 2556),
             [("01-single", "single"), ("02-duel", "duel"), ("03-settings", "settings"), ("04-start", "start")]),
            ("ipad", "ipad-13", CGSize(width: 2064, height: 2752),
             [("00-faceoff", "faceoff"), ("01-single", "single"), ("02-duel", "duel"), ("03-settings", "settings")]),
            // iPhone Duo inner display: the simulator can't be unfolded headlessly, so these use the
            // iPad captures (same wide layout as the unfolded Duo).
            ("ipad", "duo-inner", CGSize(width: 2007, height: 2853),
             [("00-faceoff", "faceoff"), ("01-single", "single"), ("02-duel", "duel"), ("03-settings", "settings")]),
        ]
        for lang in ["en", "sk"] {
            for set in sets {
                for (i, item) in set.order.enumerated() {
                    guard let img = load("\(raw)/\(set.prefix)-\(item.0)-\(lang).png"),
                          let cap = captions[item.1]?[lang] else { print("missing", set.prefix, item.0, lang); continue }
                    save(Shot(size: set.size, caption: cap, image: img),
                         "\(out)/\(set.folder)/\(lang)/\(String(format: "%02d", i + 1))-\(item.1).jpg")
                }
            }
            if let phone = load("\(raw)/iphone-01-single-\(lang).png"), let pad = load("\(raw)/ipad-00-faceoff-\(lang).png") {
                save(Banner(size: CGSize(width: 5244, height: 2950), lang: lang, phone: phone, pad: pad),
                     "\(out)/header/\(lang)/header-5244x2950.png", jpeg: false)
                save(Banner(size: CGSize(width: 3840, height: 1646), lang: lang, phone: phone, pad: pad),
                     "\(out)/header/\(lang)/header-3840x1646.jpg")
                save(Banner(size: CGSize(width: 3840, height: 2560), lang: lang, phone: phone, pad: pad),
                     "\(out)/header/\(lang)/search-3840x2560.jpg")
            }
        }
    }
}
