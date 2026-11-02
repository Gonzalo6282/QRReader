import CoreImage
import SliceQR
import SwiftUI
import UIKit

/// Draws a created code: SliceQR's code, recoloured, with the optional Qodi badge in the middle.
enum QRRenderer {
    static func image(for payload: String, colour: CodeColour, logo: Bool, side: CGFloat = 1024) -> UIImage? {
        guard let base = SliceQR.cgImage(for: payload, scale: 12, correction: logo ? .high : .medium) else { return nil }
        let ci = CIImage(cgImage: base)
        let fg = CIColor(color: UIColor(Color(hex: colour.rawValue)))
        guard let recoloured = CIFilter(name: "CIFalseColor", parameters: [
            kCIInputImageKey: ci, "inputColor0": fg, "inputColor1": CIColor(red: 1, green: 1, blue: 1),
        ])?.outputImage,
            let cg = CIContext().createCGImage(recoloured, from: recoloured.extent)
        else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let margin = side * 0.06
            context.cgContext.interpolationQuality = .none
            UIImage(cgImage: cg).draw(in: CGRect(x: margin, y: margin, width: side - 2 * margin, height: side - 2 * margin))
            guard logo else { return }
            let badge = side * 0.2
            let outer = CGRect(x: (side - badge) / 2, y: (side - badge) / 2, width: badge, height: badge)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: outer, cornerRadius: badge * 0.24).fill()
            let inner = outer.insetBy(dx: badge * 0.1, dy: badge * 0.1)
            UIColor.black.setFill()
            UIBezierPath(roundedRect: inner, cornerRadius: badge * 0.18).fill()
            let symbol = UIImage(systemName: "qrcode.viewfinder", withConfiguration: UIImage.SymbolConfiguration(pointSize: inner.width * 0.6, weight: .bold))?
                .withTintColor(UIColor(red: 0x7f / 255, green: 0xee / 255, blue: 0x64 / 255, alpha: 1), renderingMode: .alwaysOriginal)
            if let symbol {
                let s = symbol.size
                symbol.draw(in: CGRect(x: inner.midX - s.width / 2, y: inner.midY - s.height / 2, width: s.width, height: s.height))
            }
        }
    }
}
