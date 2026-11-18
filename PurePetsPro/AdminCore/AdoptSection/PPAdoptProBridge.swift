//
//  PPAdoptProBridge.swift
//  PurePetsPro
//
//  NextGen V10 Category-Defining Objective-C / UIKit Bridge for Community Adoption.
//  Permits seamless hosting of SwiftUI Adoption Control Center inside legacy ViewControllers.
//

import UIKit
import SwiftUI

@objcMembers
@MainActor
public final class PPAdoptProBridge: NSObject {

    /// Creates and returns a UIHostingController embedding the NextGen V10 Adoption Control Center
    public static func makeControlCenterController() -> UIViewController {
        let view = PPAdoptProControlCenterView()
        let host = UIHostingController(rootView: view)
        host.view.backgroundColor = UIColor.ppBackground
        return host
    }

    /// Embeds the NextGen V10 Adoption Control Center into any parent UIViewController
    public static func embedControlCenter(in parent: UIViewController) {
        let view = PPAdoptProControlCenterView()
        let host = UIHostingController(rootView: view)
        host.view.backgroundColor = UIColor.ppBackground

        parent.addChild(host)
        parent.view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: parent.view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: parent.view.bottomAnchor)
        ])

        host.didMove(toParent: parent)
    }

    /// Creates and returns a UIHostingController embedding the Detail Dossier for a pet
    public static func makeDetailController(petDict: [String: Any], documentID: String) -> UIViewController {
        let model = PPAdoptListingModel(dict: petDict, documentID: documentID) ?? PPAdoptListingModel(id: documentID, title: "Pet")
        let view = PPAdoptProDetailView(listing: model)
        let host = UIHostingController(rootView: view)
        host.view.backgroundColor = UIColor.ppBackground
        return host
    }

    /// Creates and returns a UIHostingController embedding the Edit / Create sheet
    public static func makeEditController(petDict: [String: Any]?, documentID: String?) -> UIViewController {
        let mode: PPAdoptEditMode
        if let petDict, let documentID, let model = PPAdoptListingModel(dict: petDict, documentID: documentID) {
            mode = .edit(model)
        } else {
            mode = .create
        }
        let view = PPAdoptProEditSheet(mode: mode)
        let host = UIHostingController(rootView: view)
        host.view.backgroundColor = UIColor.ppBackground
        return host
    }
}
