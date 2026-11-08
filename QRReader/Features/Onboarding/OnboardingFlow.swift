import AVFoundation
import SliceAnalytics
import SliceQR
import SliceUI
import SwiftUI

/// First run (mockup and handoff order): welcome → camera explanation → iOS camera prompt →
/// "More than your Camera app" → analytics consent (EEA/UK only) → then the onboarding paywall.
struct OnboardingFlow: View {
    enum Step { case welcome, camera, feature, consent }

    let finish: () -> Void
    @State private var step: Step = .welcome

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                switch step {
                case .welcome: welcome
                case .camera: camera
                case .feature: feature
                case .consent: consent
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .sliceTheme(QodiTheme.brand)
        .preferredColorScheme(.dark)
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            WelcomeArt().frame(maxWidth: .infinity, maxHeight: .infinity)
            Dots(step: 0)
            title("Scan any code in a second")
            lead("QR codes, barcodes, Wi-Fi and contacts. See where a link goes before you open it.")
            Button("Get started") { step = .camera }.buttonStyle(LimeButtonStyle()).accessibilityIdentifier("onboardingNext")
        }
    }

    private var camera: some View {
        VStack(alignment: .leading, spacing: 0) {
            bigIcon("camera").frame(maxWidth: .infinity, maxHeight: .infinity)
            Dots(step: 1)
            title("Allow camera access")
            lead("The camera reads codes right here on your iPhone. Nothing is recorded or uploaded.")
            Button("Continue") {
                Task {
                    if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                        let granted = await AVCaptureDevice.requestAccess(for: .video)
                        Track.log(.cameraPermission, ["result": granted ? "granted" : "denied"])
                    }
                    step = .feature
                }
            }
            .buttonStyle(LimeButtonStyle())
            Button("Scan from photos instead") { step = .feature }
                .font(.system(size: 16, weight: .medium)).foregroundStyle(QodiTheme.brand.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var feature: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("More than your Camera app").padding(.top, 56)
            lead("Your iPhone camera reads QR codes. This does the rest.")
            VStack(alignment: .leading, spacing: 18) {
                featureRow("barcode", "Barcodes too", "EAN, UPC, Code 128, Data Matrix, PDF417 and Aztec.")
                featureRow("qrcode", "Make your own QR codes", "Links, Wi-Fi and contacts. They hold your data directly and never expire.")
                featureRow("clock.arrow.circlepath", "Every scan saved", "Search past scans. They stay on this iPhone.")
                featureRow("square.on.square", "Scan in bulk", "Scan many codes in a row and export a CSV.")
            }
            Spacer()
            Dots(step: 2)
            Button("Continue") {
                if AppAnalytics.shared.requiresConsent { step = .consent } else { finish() }
            }
            .buttonStyle(LimeButtonStyle())
        }
    }

    private var consent: some View {
        VStack(alignment: .leading, spacing: 0) {
            bigIcon("chart.bar").frame(maxWidth: .infinity, maxHeight: .infinity)
            title("Help improve the app")
            lead("Share anonymous usage data, like which features you use. Never what you scan, never your photos, no tracking across apps.")
            Button("Allow") { answer(true) }.buttonStyle(LimeButtonStyle())
            Button("Don’t allow") { answer(false) }
                .font(.system(size: 16, weight: .medium)).foregroundStyle(QodiTheme.brand.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
            Text("You can change this anytime in Settings.")
                .font(.system(size: 13)).foregroundStyle(QodiTheme.brand.inkSecondary)
                .frame(maxWidth: .infinity).padding(.top, 6)
        }
    }

    private func answer(_ allowed: Bool) {
        AppAnalytics.shared.setConsent(allowed)
        Bootstrap.linkAnalytics()
        Track.log(.consent, ["analytics": allowed])
        finish()
    }

    // MARK: - Pieces

    private func title(_ text: String) -> some View {
        Text(text).font(.system(size: 34, weight: .bold)).tracking(-0.8).foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true).padding(.bottom, 12)
    }

    private func lead(_ text: String) -> some View {
        Text(text).font(.system(size: 17)).foregroundStyle(QodiTheme.brand.inkSecondary)
            .fixedSize(horizontal: false, vertical: true).padding(.bottom, 26)
    }

    private func bigIcon(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 52)).foregroundStyle(QodiTheme.lime)
            .frame(width: 120, height: 120)
            .background(QodiTheme.brand.surface, in: RoundedRectangle(cornerRadius: 32))
    }

    private func featureRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 19, weight: .semibold)).foregroundStyle(QodiTheme.lime)
                .frame(width: 42, height: 42).background(QodiTheme.brand.surface, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16.5, weight: .semibold)).foregroundStyle(.white)
                Text(detail).font(.system(size: 14.5)).foregroundStyle(QodiTheme.brand.inkSecondary)
            }
        }
        .padding(.bottom, 4)
    }
}

/// Progress dots (mockup `.dots`).
private struct Dots: View {
    let step: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(i == step ? QodiTheme.lime : Color(hex: "#2e332d")).frame(width: i == step ? 20 : 7, height: 7)
            }
        }
        .padding(.bottom, 22)
        .accessibilityHidden(true)
    }
}

/// A code on a card with the reticle locking onto it (mockup `.demo-lock`).
private struct WelcomeArt: View {
    @State private var locked = false

    var body: some View {
        ZStack {
            Group {
                if let image = SliceQR.image(for: "https://slice-of-life.uk/qr", scale: 8) {
                    Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                }
            }
            .padding(10)
            .frame(width: 128, height: 128)
            .background(Color(hex: "#f6f3ec"), in: RoundedRectangle(cornerRadius: 10))
            .rotationEffect(.degrees(-6))
            .shadow(color: .black.opacity(0.5), radius: 15, y: 16)
            ReticleCorners()
                .stroke(QodiTheme.lime, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .shadow(color: QodiTheme.lime.opacity(0.55), radius: 6)
                .frame(width: locked ? 150 : 210, height: locked ? 150 : 210)
        }
        .frame(width: 220, height: 220)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { locked = true }
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeInOut(duration: 0.5)) { locked = false }
            }
        }
        .accessibilityHidden(true)
    }
}
