import ContactsUI
import EventKit
import EventKitUI
import ScanKit
import SwiftUI
import UIKit

/// Apple's new-contact card (no Contacts permission needed to show it).
struct NewContactSheet: UIViewControllerRepresentable {
    let contact: CNMutableContact
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = CNContactViewController(forNewContact: contact)
        controller.contactStore = CNContactStore()
        controller.delegate = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            onDone()
        }
    }
}

/// Apple's event editor, filled from the code (iOS 17 shows it without Calendar permission).
struct NewEventSheet: UIViewControllerRepresentable {
    let event: CalendarEvent
    let onDone: () -> Void
    private let store = EKEventStore()

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = store
        let e = EKEvent(eventStore: store)
        e.title = event.summary
        let start = event.start?.date() ?? .now
        e.startDate = start
        e.endDate = event.end?.date() ?? start.addingTimeInterval(event.start?.isAllDay == true ? 86_400 : 3_600)
        e.isAllDay = event.start?.isAllDay ?? false
        e.location = event.location
        e.notes = event.details
        controller.event = e
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onDone()
        }
    }
}
