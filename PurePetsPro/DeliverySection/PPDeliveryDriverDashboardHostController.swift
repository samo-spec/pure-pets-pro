//
//  PPDeliveryDriverDashboardHostController.swift
//  PurePetsPro
//
//  UIKit Host Controller bridging the Category-Defining SwiftUI Delivery Driver Cockpit
//  into the Pro application navigation architecture.
//

import UIKit
import SwiftUI

@objcMembers
public final class PPDeliveryDriverDashboardHostController: UIViewController {

    private var hostingController: UIHostingController<PPDeliveryDriverControlView>?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.ppBackground
        setupHostingController()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.title = Language.get("Deliv_Cockpit_Title", alter: "غرفة عمليات التوصيل")
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupHostingController() {
        let rootView = PPDeliveryDriverControlView()
        let host = UIHostingController(rootView: rootView)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(host)
        view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        host.didMove(toParent: self)
        self.hostingController = host
    }
}
