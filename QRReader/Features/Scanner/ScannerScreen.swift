import SliceUI
import Foundation
import PhotosUI
import ScanKit
import SlicePurchases
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The Scan tab (mockup `vScan`): dark camera, lime reticle, torch, zoom, photo button and Batch.
struct ScannerScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @State private var camera = CameraController()
    @State private var showsPhotoPicker = false
    @State private var showsFiles = false
    @State private var photoItem: PhotosPickerItem?
    @State private var noCodeFound = false
    @State private var pinchBase: CGFloat = 1
    @State private var sweeping = false
    @State private var flash = false

    var body: some View {
        @Bindable var app = app
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if camera.isDenied { cameraOff } else { live }
            topBar
        }
        .task {
            camera.onCode = { code in scanned(code) }
            await camera.appear()
        }
        .onDisappear { camera.disappear() }
        .onChange(of: app.result == nil) { _, closed in
            if closed { camera.resume() }
        }
        .photosPicker(isPresented: $showsPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task { await scanPhoto(item) }
        }
        .fileImporter(isPresented: $showsFiles, allowedContentTypes: [.image, .pdf]) { result in
            guard case .success(let url) = result else { return }
            Task {
                let codes = await Task.detached { PhotoScanner.codes(inFile: url) }.value
                deliverPhoto(codes)
            }
        }
        .alert("No code found in this photo", isPresented: $noCodeFound) {
            Button("Close", role: .cancel) {}
            Button("Pick another") { showsPhotoPicker = true }
        } message: {
            Text("Try a sharper photo, or crop closer to the code. Codes need to be in focus and not cut off at the edges.")
        }
        .sheet(isPresented: $app.showsBatchList) { BatchListView() }
    }

    // MARK: - Live camera

    private var live: some View {
        GeometryReader { geo in
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.41)
            let side: CGFloat = camera.locked ? 200 : 250
            ZStack {
                if ScreenshotMode.isOn {
                    ScreenshotScene()
                } else {
                    CameraPreview(session: camera.scanner.session).ignoresSafeArea()
                }
                if flash {
                    RoundedRectangle(cornerRadius: 12).fill(QodiTheme.lime.opacity(0.16))
                        .frame(width: 180, height: 180).position(centre).transition(.opacity)
                }
                ReticleCorners()
                    .stroke(QodiTheme.lime, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .shadow(color: QodiTheme.lime.opacity(0.55), radius: 6)
                    .frame(width: side, height: side)
                    .position(centre)
                    .animation(.spring(response: 0.38, dampingFraction: 0.55), value: camera.locked)
                if !camera.locked {
                    LinearGradient(colors: [.clear, QodiTheme.lime, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 210, height: 2).opacity(0.7)
                        .position(x: centre.x, y: centre.y + (sweeping ? 100 : -100))
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: sweeping)
                        .onAppear { sweeping = true }
                        .accessibilityHidden(true)
                }
                Text(app.batchMode ? "Batch mode: keep scanning" : "Point at a QR code or barcode")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
                    .position(x: centre.x, y: centre.y + 150)
                zoomPill.position(x: centre.x, y: centre.y + 190)
                if app.batchMode, !app.batch.isEmpty {
                    Button { app.showsBatchList = true } label: {
                        Label("\(app.batch.count) \(app.batch.count == 1 ? "code" : "codes") · View list", systemImage: "square.on.square")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(QodiTheme.onLime)
                            .padding(.horizontal, 16).frame(height: 40)
                            .background(QodiTheme.lime, in: Capsule())
                            .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
                    }
                    .position(x: centre.x, y: geo.size.height - 40)
                    .accessibilityIdentifier("batchTray")
                }
            }
            .contentShape(Rectangle())
            .gesture(MagnifyGesture()
                .onChanged { value in camera.setZoom(pinchBase * value.magnification, animated: false) }
                .onEnded { _ in pinchBase = camera.zoom })
        }
    }

    private var zoomPill: some View {
        HStack(spacing: 6) {
            ForEach([1, 2], id: \.self) { z in
                let on = Int(camera.zoom.rounded()) == z
                Button("\(z)×") {
                    camera.setZoom(CGFloat(z), animated: true)
                    pinchBase = CGFloat(z)
                }
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(on ? QodiTheme.lime : .white)
                .frame(width: 34, height: 34)
                .background(on ? Color.white.opacity(0.18) : .clear, in: Circle())
            }
        }
        .padding(4)
        .background(Color(white: 0.08).opacity(0.6), in: Capsule())
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Menu {
                Button { showsPhotoPicker = true } label: { Label("Choose a photo", systemImage: "photo") }
                Button { showsFiles = true } label: { Label("Choose a file or PDF", systemImage: "folder") }
            } label: {
                roundIcon("photo", on: false)
            }
            .accessibilityLabel("Scan from photos or files")
            Spacer()
            Button { app.toggleBatch() } label: {
                HStack(spacing: 7) {
                    Image(systemName: "square.on.square").font(.system(size: 14, weight: .semibold))
                    Text("Batch")
                    if !PurchaseManager.shared.isPremium { Image(systemName: "lock.fill").font(.system(size: 11)) }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(app.batchMode ? QodiTheme.onLime : .white)
                .padding(.horizontal, 14).frame(height: 36)
                .background(app.batchMode ? AnyShapeStyle(QodiTheme.lime) : AnyShapeStyle(.ultraThinMaterial.opacity(0.9)), in: Capsule())
            }
            .accessibilityIdentifier("batchChip")
            Spacer()
            Button { camera.torchOn.toggle() } label: { roundIcon(camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill", on: camera.torchOn) }
                .accessibilityLabel("Torch")
                .disabled(camera.isDenied)
        }
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func roundIcon(_ name: String, on: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(on ? QodiTheme.onLime : .white)
            .frame(width: 44, height: 44)
            .background(on ? AnyShapeStyle(QodiTheme.lime) : AnyShapeStyle(.ultraThinMaterial.opacity(0.9)), in: Circle())
    }

    // MARK: - Camera off

    private var cameraOff: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash").font(.system(size: 46)).foregroundStyle(QodiTheme.brand.inkSecondary)
            Text("Camera access is off").font(.system(size: 22, weight: .bold)).foregroundStyle(.white).padding(.top, 8)
            Text("Turn on the camera in Settings to scan live. You can still scan codes in photos and screenshots.")
                .font(.system(size: 15)).foregroundStyle(QodiTheme.brand.inkSecondary).multilineTextAlignment(.center)
                .padding(.bottom, 10)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(LimeButtonStyle())
            .frame(width: 240)
            Button("Scan from a photo") { showsPhotoPicker = true }
                .font(.system(size: 16, weight: .medium)).foregroundStyle(QodiTheme.brand.inkSecondary).frame(height: 44)
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("cameraOff")
    }

    // MARK: - Results

    private func scanned(_ code: ScannedCode) {
        withAnimation(.easeOut(duration: 0.1)) { flash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.35)) { flash = false }
            app.handle(code, from: .camera, context: context)
            if app.batchMode {
                try? await Task.sleep(for: .milliseconds(700))
                camera.resume()
            }
        }
    }

    private func scanPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            noCodeFound = true
            return
        }
        let codes = await Task.detached { PhotoScanner.codes(inImageData: data) }.value
        deliverPhoto(codes)
    }

    private func deliverPhoto(_ codes: [ScannedCode]) {
        guard let first = codes.first else {
            noCodeFound = true
            return
        }
        app.handle(first, from: .photo, context: context)
    }
}
