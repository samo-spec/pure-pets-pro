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

    private var hostingController: UIViewController?
    private var driverStore: PPDriverCockpitStore?
    private var onDismissCallback: (() -> Void)?
    private var isVisible = false
    private var pendingEntry: Bool?
    private var requestGeneration = 0
    private let entryScroll = UIScrollView()
    private let entryStack = UIStackView()
    private let activity = UIActivityIndicatorView(style: .medium)
    private let entryMessage = UILabel()
    private let retryButton = UIButton(type: .system)

    @objc public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.onDismissCallback = nil
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    @objc public convenience init(onDismiss: (() -> Void)? = nil) {
        self.init(nibName: nil, bundle: nil)
        self.onDismissCallback = onDismiss
    }

    @objc public convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.onDismissCallback = nil
        super.init(coder: coder)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.ppBackground
        view.semanticContentAttribute = Language.isRTL() ? .forceRightToLeft : .forceLeftToRight
        title = ppDriverText("DriverCockpit_Title")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close,
                                                         target: self, action: #selector(closeEntry))
        setupEntryStatus()
        resolveEntry()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isVisible = true
        driverStore?.start(focus: nil)
        driverStore?.setVisible(true)
        if let pendingEntry, hostingController == nil {
            self.pendingEntry = nil
            showResolvedEntry(requiresDriverCockpit: pendingEntry)
        }
        navigationController?.setNavigationBarHidden(hostingController != nil, animated: animated)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isVisible = false
        driverStore?.setVisible(false)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupEntryStatus() {
        entryScroll.translatesAutoresizingMaskIntoConstraints = false
        entryScroll.alwaysBounceVertical = false
        entryStack.axis = .vertical
        entryStack.spacing = 16
        entryStack.translatesAutoresizingMaskIntoConstraints = false
        entryMessage.font = UIFont.preferredFont(forTextStyle: .body)
        entryMessage.adjustsFontForContentSizeCategory = true
        entryMessage.textColor = .ppTextSecondary
        entryMessage.textAlignment = Language.alignmentForCurrentLanguage()
        entryMessage.numberOfLines = 0
        retryButton.setTitle(ppDriverText("TryAgain"), for: .normal)
        retryButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        retryButton.tintColor = .ppPrimary
        retryButton.addTarget(self, action: #selector(resolveEntry), for: .touchUpInside)
        retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        let statusViews: [UIView] = [activity, entryMessage, retryButton]
        statusViews.forEach { entryStack.addArrangedSubview($0) }
        activity.isAccessibilityElement = false
        view.addSubview(entryScroll)
        entryScroll.addSubview(entryStack)
        NSLayoutConstraint.activate([
            entryScroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            entryScroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            entryScroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            entryScroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            entryStack.leadingAnchor.constraint(equalTo: entryScroll.contentLayoutGuide.leadingAnchor, constant: 24),
            entryStack.trailingAnchor.constraint(equalTo: entryScroll.contentLayoutGuide.trailingAnchor, constant: -24),
            entryStack.topAnchor.constraint(equalTo: entryScroll.contentLayoutGuide.topAnchor, constant: 24),
            entryStack.bottomAnchor.constraint(equalTo: entryScroll.contentLayoutGuide.bottomAnchor, constant: -24),
            entryStack.widthAnchor.constraint(equalTo: entryScroll.frameLayoutGuide.widthAnchor, constant: -48),
        ])
    }

    @objc private func resolveEntry() {
        requestGeneration += 1
        let generation = requestGeneration
        let requestedUID = PPDeliveryCompanyService.currentAccountUID()
        entryMessage.text = ppDriverText("DriverCockpit_Loading_Tasks")
        retryButton.isHidden = true
        activity.startAnimating()
        PPDeliveryCompanyService.shared().resolveDriverCockpitRequirement { [weak self] requiresDriverCockpit, error in
            Task { @MainActor [weak self] in
                guard let self, generation == self.requestGeneration,
                      requestedUID == PPDeliveryCompanyService.currentAccountUID() else { return }
                self.activity.stopAnimating()
                if let error {
                    self.entryMessage.text = (error as NSError).code == 403
                        ? error.localizedDescription : ppDriverText("DeliveryLogin_CheckFailed_Body")
                    self.retryButton.isHidden = false
                    return
                }
                guard self.isVisible else {
                    self.pendingEntry = requiresDriverCockpit
                    return
                }
                self.showResolvedEntry(requiresDriverCockpit: requiresDriverCockpit)
            }
        }
    }

    private func showResolvedEntry(requiresDriverCockpit: Bool) {
        guard hostingController == nil else { return }
        entryScroll.isHidden = true
        if requiresDriverCockpit {
            let store = PPDriverCockpitStore()
            driverStore = store
            let host = UIHostingController(rootView: PPDriverCockpitView(store: store, onClose: { [weak self] in
                self?.closeEntry()
            }))
            embed(host)
            store.start(focus: nil)
            store.setVisible(isVisible)
        } else {
            setupProviderHostingController()
        }
        if isVisible { navigationController?.setNavigationBarHidden(true, animated: false) }
    }

    @objc private func closeEntry() {
        if let callback = onDismissCallback { callback() }
        else if let nav = navigationController, nav.viewControllers.count > 1 { nav.popViewController(animated: true) }
        else { dismiss(animated: true) }
    }

    private func setupProviderHostingController() {
        let rootView = PPDeliveryDriverControlView(onDismiss: { [weak self] in
            self?.closeEntry()
        }, onOpenRecord: { [weak self] order in
            // Full UIKit record: chat, report issue, map and distance.
            guard let nav = self?.navigationController else { return }
            let record = PPDeliveryOrderDetailViewController(order: order)
            record.hidesBottomBarWhenPushed = true
            nav.pushViewController(record, animated: true)
        })
        let host = UIHostingController(rootView: rootView)
        embed(host)
    }

    private func embed(_ host: UIViewController) {
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
