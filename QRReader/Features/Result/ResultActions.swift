import Foundation
import Contacts
import EventKit
import NetworkExtension
import ScanKit
import UIKit

/// What a result action needs from the screen after it runs.
enum ActionOutcome {
    case toast(String, icon: String)
    case share([Any])
    case addContact(CNMutableContact)
    case addEvent(CalendarEvent)
    case nothing
}

/// Runs result-card actions (Build Doc row 4). Links always open in Safari, never inside the app (4+ rating).
enum ResultActions {
    static func perform(_ action: ResultAction, payload: Payload, raw: String) async -> ActionOutcome {
        Track.log(.resultAction, ["type": action.analyticsName])
        switch action {
        case .open:
            if case .url(let url) = payload { _ = await UIApplication.shared.open(url) }
            return .nothing
        case .copyLink, .copy, .copyText:
            return copy(raw, message: "Copied")
        case .copyPassword:
            if case .wifi(let w) = payload { return copy(w.password ?? "", message: "Password copied") }
            return .nothing
        case .copyNumber:
            if case .phone(let n) = payload { return copy(n, message: "Number copied") }
            return copy(raw, message: "Copied")
        case .copyAddress:
            if case .email(let e) = payload { return copy(e.address, message: "Address copied") }
            return copy(raw, message: "Copied")
        case .share:
            if case .url(let url) = payload { return .share([url]) }
            return .share([raw])
        case .join:
            guard case .wifi(let w) = payload else { return .nothing }
            return await join(w)
        case .contact:
            guard case .contact(let c) = payload else { return .nothing }
            return .addContact(cnContact(c))
        case .calendar:
            guard case .event(let e) = payload else { return .nothing }
            return .addEvent(e)
        case .call:
            let number: String? = switch payload {
            case .phone(let n): n
            case .contact(let c): c.phones.first
            default: nil
            }
            if let number { await open(QRPayloadBuilder.phone(number)) }
            return .nothing
        case .mail, .writeEmail:
            let email: Email? = switch payload {
            case .email(let e): e
            case .contact(let c): c.emails.first.map { Email(address: $0) }
            default: nil
            }
            if let email { await open(QRPayloadBuilder.email(email)) }
            return .nothing
        case .sms:
            if case .sms(let s) = payload {
                let body = s.body.map { "&body=" + ($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") } ?? ""
                let number = String(QRPayloadBuilder.phone(s.number).dropFirst(4))
                await open("sms:" + number + body)
            }
            return .nothing
        case .maps:
            if case .geo(let g) = payload {
                let label = (g.query ?? "Location").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                await open("https://maps.apple.com/?ll=\(g.latitude),\(g.longitude)&q=\(label)")
            }
            return .nothing
        case .search:
            await open("x-web-search://?" + (raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw))
            return .nothing
        }
    }

    private static func copy(_ text: String, message: String) -> ActionOutcome {
        UIPasteboard.general.string = text
        return .toast(message, icon: "doc.on.doc")
    }

    private static func open(_ string: String) async {
        guard let url = URL(string: string) else { return }
        _ = await UIApplication.shared.open(url)
    }

    /// Wi-Fi join (Hotspot Configuration capability). Failure wording from the handoff.
    static func join(_ w: WiFi) async -> ActionOutcome {
        let configuration: NEHotspotConfiguration
        switch (w.security, w.password) {
        case (.open, _), (_, nil): configuration = NEHotspotConfiguration(ssid: w.ssid)
        case (.wep, let pw?): configuration = NEHotspotConfiguration(ssid: w.ssid, passphrase: pw, isWEP: true)
        case (.wpa, let pw?): configuration = NEHotspotConfiguration(ssid: w.ssid, passphrase: pw, isWEP: false)
        }
        configuration.joinOnce = false
        do {
            try await NEHotspotConfigurationManager.shared.apply(configuration)
            return .toast("Joined \(w.ssid)", icon: "wifi")
        } catch {
            let ns = error as NSError
            if ns.domain == NEHotspotConfigurationErrorDomain {
                if ns.code == NEHotspotConfigurationError.alreadyAssociated.rawValue { return .toast("Joined \(w.ssid)", icon: "wifi") }
                if ns.code == NEHotspotConfigurationError.userDenied.rawValue { return .nothing }
            }
            return .toast("Couldn’t join \(w.ssid). The password in this code may be out of date. Ask for a new code.",
                          icon: "exclamationmark.triangle.fill")
        }
    }

    static func cnContact(_ c: Contact) -> CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = c.givenName ?? (c.familyName == nil ? c.fullName : "")
        contact.familyName = c.familyName ?? ""
        contact.organizationName = c.organization ?? ""
        contact.jobTitle = c.title ?? ""
        contact.phoneNumbers = c.phones.map { CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0)) }
        contact.emailAddresses = c.emails.map { CNLabeledValue(label: CNLabelWork, value: $0 as NSString) }
        contact.urlAddresses = c.urls.map { CNLabeledValue(label: CNLabelURLAddressHomePage, value: $0 as NSString) }
        if let address = c.address {
            let postal = CNMutablePostalAddress()
            postal.street = address
            contact.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: postal)]
        }
        if let note = c.note { contact.note = note }
        return contact
    }
}
