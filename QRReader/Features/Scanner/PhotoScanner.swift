import CoreImage
import ImageIO
import PDFKit
import ScanKit
import UIKit
import UniformTypeIdentifiers
import Vision

/// Reads codes in photos, screenshots and PDFs (Build Doc row 2). Free, like the camera.
nonisolated enum PhotoScanner {
    /// Codes in an image, trying the inverted image too (white-on-black codes).
    static func codes(in image: CGImage, tryInverted: Bool = true) -> [ScannedCode] {
        let found = detect(image)
        if !found.isEmpty || !tryInverted { return found }
        let ci = CIImage(cgImage: image)
        guard let inverted = CIFilter(name: "CIColorInvert", parameters: [kCIInputImageKey: ci])?.outputImage,
              let cg = CIContext().createCGImage(inverted, from: inverted.extent)
        else { return [] }
        return detect(cg)
    }

    static func codes(inImageData data: Data) -> [ScannedCode] {
        guard let image = cgImage(from: data) else { return [] }
        return codes(in: image)
    }

    /// An image or PDF picked in Files. PDFs: every page, up to 20.
    static func codes(inFile url: URL) -> [ScannedCode] {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true {
            guard let document = PDFDocument(url: url) else { return [] }
            for index in 0..<min(document.pageCount, 20) {
                guard let page = document.page(at: index),
                      let image = page.thumbnail(of: CGSize(width: 2200, height: 2200), for: .mediaBox).cgImage
                else { continue }
                let found = codes(in: image)
                if !found.isEmpty { return found }
            }
            return []
        }
        guard let data = try? Data(contentsOf: url) else { return [] }
        return codes(inImageData: data)
    }

    private static func detect(_ image: CGImage) -> [ScannedCode] {
        let request = VNDetectBarcodesRequest()
        try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let raw = observation.payloadStringValue, !raw.isEmpty,
                  let format = BarcodeFormat(systemName: observation.symbology.rawValue)
            else { return nil }
            return ScannedCode(raw: raw, format: format)
        }
    }

    /// Decodes with the photo's orientation applied, at most 3000 px on the long side.
    private static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 3000,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
