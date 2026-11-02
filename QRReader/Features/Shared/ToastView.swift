import SwiftUI

/// The mockup's toast: dark capsule near the top with a lime icon.
struct ToastView: View {
    let toast: AppModel.Toast

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: toast.icon).foregroundStyle(QodiTheme.lime).font(.system(size: 18, weight: .semibold))
            Text(toast.text).font(.system(size: 14.5)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(white: 0.1).opacity(0.94), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.35), radius: 15, y: 10)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("toast")
        .accessibilityElement(children: .combine)
    }
}
