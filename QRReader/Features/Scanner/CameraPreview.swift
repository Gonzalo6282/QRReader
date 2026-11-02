import AVFoundation
import SwiftUI
import UIKit

/// The live camera picture.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer?.session = session
        view.previewLayer?.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}
}

/// The lime corner reticle (mockup `.reticle`).
struct ReticleCorners: Shape {
    var length: CGFloat = 38
    var radius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let l = length, r = radius
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1), (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1), (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
        ]
        for (c, dx, dy) in corners {
            p.move(to: CGPoint(x: c.x, y: c.y + dy * l))
            p.addLine(to: CGPoint(x: c.x, y: c.y + dy * r))
            p.addQuadCurve(to: CGPoint(x: c.x + dx * r, y: c.y), control: c)
            p.addLine(to: CGPoint(x: c.x + dx * l, y: c.y))
        }
        return p
    }
}
