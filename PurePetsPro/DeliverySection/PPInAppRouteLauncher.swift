//
//  PPInAppRouteLauncher.swift
//  PurePetsPro
//
//  Objective-C / UIKit bridge to present the In-App Google Maps Live Route modal
//  from any UIViewController in Pure Pets Pro.
//

import UIKit
import SwiftUI

@MainActor
@objc public final class PPInAppRouteLauncher: NSObject {

    @objc public static func presentRoute(from parent: UIViewController, order: PPDeliveryOrderModel) {
        weak var hostingController: UIHostingController<PPInAppRouteModalView>?

        let rootView = PPInAppRouteModalView(order: order) {
            hostingController?.dismiss(animated: true, completion: nil)
        }

        let host = UIHostingController(rootView: rootView)
        hostingController = host
        host.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        host.view.backgroundColor = UIColor.black
        parent.present(host, animated: true, completion: nil)
    }

    @objc public static func presentRoute(
        from parent: UIViewController,
        orderNumber: String,
        pickupAddress: String,
        dropoffAddress: String,
        isPickupDefault: Bool
    ) {
        weak var hostingController: UIHostingController<PPInAppRouteModalView>?

        let pAddress = PPDriverAddress(primary: pickupAddress, secondary: "", mapQuery: pickupAddress, phone: "")
        let dAddress = PPDriverAddress(primary: dropoffAddress, secondary: "", mapQuery: dropoffAddress, phone: "")

        let rootView = PPInAppRouteModalView(
            orderNumber: orderNumber,
            pickupAddress: pAddress,
            dropoffAddress: dAddress,
            initialStop: isPickupDefault ? .pickup : .dropoff
        ) {
            hostingController?.dismiss(animated: true, completion: nil)
        }

        let host = UIHostingController(rootView: rootView)
        hostingController = host
        host.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        host.view.backgroundColor = UIColor.black
        parent.present(host, animated: true, completion: nil)
    }
}
