import UIKit
import SwiftUI

// MARK: - Official Root Tab Bar for Pure Pets Pro
//
// Replaces the custom SwiftUI dock (PPProPulseDock) with a system UITabBarController
// that lives at the window root. Four persistent lanes mirror the former dock:
//
//  • Pulse (dashboard)      – waveform.path.ecg
//  • Menu / Atlas (map)     – square.grid.2x2
//  • Notifications / Inbox  – bell
//  • More                   – ellipsis
//
// The transient "Work" action from the former dock is not a persistent tab; its
// operation remains reachable inside Pulse's decision stage and queue. This
// matches the Admin tab-bar contract (Dashboard / Chats / Notifications / Settings)
// and keeps the UITabBar to four items for density and reachability.
//
// All titles, badges and RTL handling use the existing Language and Styling
// contracts; appearance mirrors PurePetsAdmin's pp_buildDashboardTabBarController.

@objcMembers
public final class PPProRootTabBarController: UITabBarController, UITabBarControllerDelegate {

    // MARK: State
    private var dashboardVC: UIViewController!
    private var menuHostNav: UINavigationController!
    private var notifNav: UINavigationController!
    private var moreHostNav: UINavigationController!

    private var notificationBadgeCount: Int = 0

    // MARK: Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        configureAppearance()
        buildTabs()
        observeLanguageChanges()
        // Semantic for RTL
        view.semanticContentAttribute = Language.isRTL() ? .forceRightToLeft : .forceLeftToRight
        tabBar.semanticContentAttribute = Language.isRTL() ? .forceRightToLeft : .forceLeftToRight
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Appearance

    private func configureAppearance() {
        let tintColor = UIColor.ppPrimary
        let unselected = UIColor.ppTextSecondary.withAlphaComponent(0.72)

        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: Styling.fontMedium(10),
            .foregroundColor: unselected
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .font: Styling.fontMedium(10),
            .foregroundColor: tintColor
        ]

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
            appearance.inlineLayoutAppearance.normal.titleTextAttributes = normalAttrs
            appearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs
            appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalAttrs
            appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        } else {
            UITabBarItem.appearance().setTitleTextAttributes(normalAttrs, for: .normal)
            UITabBarItem.appearance().setTitleTextAttributes(selectedAttrs, for: .selected)
        }
        tabBar.tintColor = tintColor
        tabBar.unselectedItemTintColor = unselected
        // 1px hairline is supplied by UITabBarAppearance; ensure translucent blur
        tabBar.isTranslucent = true
    }

    // MARK: Tabs

    private func buildTabs() {
        // --- Pulse / Dashboard ---
        // Use NSClassFromString so we avoid hard import dependency in Swift
        let dashClass: UIViewController.Type? = NSClassFromString("AdminDashboardViewController") as? UIViewController.Type
        let dashVCInstance: UIViewController = dashClass?.init() ?? UIViewController()
        dashboardVC = dashVCInstance

        let dashNav = UINavigationController(rootViewController: dashboardVC)
        // Apply nav appearance if the category exists
        if dashNav.responds(to: Selector(("pp_applyPurePetsNavAppearance"))) {
            dashNav.perform(Selector(("pp_applyPurePetsNavAppearance")))
        }
        let pulseTitle = Language.get("PulseCommand_Dock_Pulse", alter: "Pulse")
        let pulseIcon = UIImage(systemName: "waveform.path.ecg")
        let pulseSelected = UIImage(systemName: "waveform.path.ecg")
        dashNav.tabBarItem = UITabBarItem(title: pulseTitle, image: pulseIcon, selectedImage: pulseSelected)
        dashNav.tabBarItem.tag = 0
        dashNav.tabBarItem.accessibilityLabel = pulseTitle

        // --- Menu / Atlas ---
        //
        // This tab used to be `PPProMenuTableViewController`: a **static**
        // ten-entry array — Marketplace, Pharmacy, Services, Veterinary, Delivery
        // Company, Delivery, Adoption, Fulfillment, Notifications, Support — shown
        // to every provider regardless of capability, each row pushing its
        // controller straight through `NSClassFromString`.
        //
        // Before this tab bar existed, Menu was `PPProMenuMapView`, which renders
        // only `snapshot.capabilities`: the set `pp_refreshCommandCenterSnapshot`
        // built behind `pp_canManageMarketplace`, `pp_canManagePharmacy`,
        // `pp_canManageServices`, `pp_canManageVets`, `pp_canManageDelivery`
        // (including the `PPProviderTypeIsEnabledInProApp` kill switch),
        // `pp_hasDeliveryCompanyWorkspaceForUser:` and `pp_canManageAdoption`.
        // The static array silently dropped every one of those gates.
        //
        // The container below restores the permission-derived source, and fails
        // closed: until the dashboard's command-center surface exists there is
        // nothing to list, and it does not fall back to the ungated array.
        let menuHost = PPProSurfaceTabController()
        menuHost.title = Language.get("PulseCommand_Dock_MenuMap", alter: "Menu")
        menuHost.navigationItem.largeTitleDisplayMode = .never
        menuHost.dashboardProvider = { [weak self] in self?.dashboardVC }
        let menuNav = UINavigationController(rootViewController: menuHost)
        menuHost.makeChild = { [weak self, weak menuNav] surface in
            surface.makeMenuMapViewController { route in
                self?.pushRoute(route, in: menuNav)
            }
        }
        if menuNav.responds(to: Selector(("pp_applyPurePetsNavAppearance"))) {
            menuNav.perform(Selector(("pp_applyPurePetsNavAppearance")))
        }
        let menuTitle = Language.get("PulseCommand_Dock_MenuMap", alter: "Menu")
        menuNav.tabBarItem = UITabBarItem(title: menuTitle,
                                          image: UIImage(systemName: "square.grid.2x2"),
                                          selectedImage: UIImage(systemName: "square.grid.2x2.fill"))
        menuNav.tabBarItem.tag = 1
        menuNav.tabBarItem.accessibilityLabel = menuTitle
        menuHostNav = menuNav

        // --- Notifications / Inbox ---
        let notifClass: UIViewController.Type? = NSClassFromString("NotificationsListViewController") as? UIViewController.Type
        let notifVC = notifClass?.init() ?? UIViewController()
        let notifNavInstance = UINavigationController(rootViewController: notifVC)
        if notifNavInstance.responds(to: Selector(("pp_applyPurePetsNavAppearance"))) {
            notifNavInstance.perform(Selector(("pp_applyPurePetsNavAppearance")))
        }
        let notifTitle = Language.get("NotificationsTitle", alter: "Inbox")
        notifNavInstance.tabBarItem = UITabBarItem(title: notifTitle,
                                                   image: UIImage(systemName: "bell"),
                                                   selectedImage: UIImage(systemName: "bell.fill"))
        notifNavInstance.tabBarItem.tag = 2
        notifNavInstance.tabBarItem.accessibilityLabel = notifTitle
        notifNav = notifNavInstance

        // --- More ---
        //
        // Same correction as the Menu tab: the static `PPProMoreTableViewController`
        // listed Support Chats, Fulfillment, Branches, Company Members and both
        // settings rows unconditionally, while `buildLoginForm` builds those rows
        // only behind `isAnyActiveProvider` / `canManageServices ||
        // canManageMarketplace`. The store-driven `PPProMoreView` now derives its
        // entries from the granted capability set instead.
        let moreHost = PPProSurfaceTabController()
        moreHost.title = Language.get("PulseCommand_Dock_More", alter: "More")
        moreHost.navigationItem.largeTitleDisplayMode = .never
        moreHost.dashboardProvider = { [weak self] in self?.dashboardVC }
        let moreNavInstance = UINavigationController(rootViewController: moreHost)
        moreHost.makeChild = { [weak self, weak moreNavInstance] surface in
            surface.makeMoreViewController(
                onRoute: { route in
                    self?.pushRoute(route, in: moreNavInstance)
                },
                onProfile: {
                    self?.pushRoute("profileSettings", in: moreNavInstance)
                }
            )
        }
        if moreNavInstance.responds(to: Selector(("pp_applyPurePetsNavAppearance"))) {
            moreNavInstance.perform(Selector(("pp_applyPurePetsNavAppearance")))
        }
        let moreTitle = Language.get("PulseCommand_Dock_More", alter: "More")
        moreNavInstance.tabBarItem = UITabBarItem(title: moreTitle,
                                                  image: UIImage(systemName: "ellipsis"),
                                                  selectedImage: UIImage(systemName: "ellipsis"))
        moreNavInstance.tabBarItem.tag = 3
        moreNavInstance.tabBarItem.accessibilityLabel = moreTitle
        moreHostNav = moreNavInstance

        viewControllers = [dashNav, menuNav, notifNavInstance, moreNavInstance]

        // Restore badge if already known
        if notificationBadgeCount > 0 {
            updateNotificationBadge(notificationBadgeCount)
        }

        // Ensure selected is Pulse on first build
        selectedIndex = 0
    }

    // MARK: Language

    private func observeLanguageChanges() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleLanguageChange),
                                               name: NSNotification.Name("LanguageDidChangeNotification"),
                                               object: nil)
    }

    @objc private func handleLanguageChange() {
        // Rebuild titles and semantic
        view.semanticContentAttribute = Language.isRTL() ? .forceRightToLeft : .forceLeftToRight
        tabBar.semanticContentAttribute = Language.isRTL() ? .forceRightToLeft : .forceLeftToRight
        // Update titles in place without recreating stack to preserve nav history
        let pulseTitle = Language.get("PulseCommand_Dock_Pulse", alter: "Pulse")
        let menuTitle = Language.get("PulseCommand_Dock_MenuMap", alter: "Menu")
        let notifTitle = Language.get("NotificationsTitle", alter: "Inbox")
        let moreTitle = Language.get("PulseCommand_Dock_More", alter: "More")
        viewControllers?[0].tabBarItem.title = pulseTitle
        viewControllers?[1].tabBarItem.title = menuTitle
        viewControllers?[2].tabBarItem.title = notifTitle
        viewControllers?[3].tabBarItem.title = moreTitle
        // Titles on hosted VCs also need refresh for nav bar visible title
        (menuHostNav?.viewControllers.first as? UIViewController)?.title = menuTitle
        (moreHostNav?.viewControllers.first as? UIViewController)?.title = moreTitle
    }

    @objc public func refreshForLanguageChange() {
        handleLanguageChange()
    }

    // MARK: Badges

    @objc public func updateNotificationBadge(_ count: Int) {
        notificationBadgeCount = max(0, count)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.viewControllers?.count ?? 0 > 2 else { return }
            let item = self.viewControllers?[2].tabBarItem
            if self.notificationBadgeCount > 0 {
                item?.badgeValue = self.notificationBadgeCount > 99 ? "99+" : "\(self.notificationBadgeCount)"
                item?.badgeColor = UIColor.ppPrimary
            } else {
                item?.badgeValue = nil
            }
        }
    }

    @objc public func updateCombinedBadge(inbox: Int, support: Int) {
        updateNotificationBadge(inbox + support)
    }

    @objc public func updateNotificationBadgeNumber(_ number: NSNumber) {
        updateNotificationBadge(number.intValue)
    }

    @objc public func updateCombinedBadgeNumber(inbox: NSNumber, support: NSNumber) {
        updateCombinedBadge(inbox: inbox.intValue, support: support.intValue)
    }

    // MARK: Routing

    private func pushRoute(_ route: String, in nav: UINavigationController?) {
        guard let nav, !route.isEmpty else { return }
        // Special routes that are handled by dashboard's dispatcher
        if route == "__menuMap" || route == "__more" || route == "__dockPopToRoot" || route == "__retryCommandData" {
            // Menu/more tabs are themselves those destinations; for other special routes,
            // forward to dashboard's dispatcher if possible.
            if route == "__dockPopToRoot" {
                selectedIndex = 0
                if let dashNav = viewControllers?.first as? UINavigationController {
                    dashNav.popToRootViewController(animated: true)
                }
                return
            }
            // Unsupported special: ignore
            return
        }
        // Handle vet alias
        let normalized = route == "__vet" ? "vetList" : route
        if let vc = viewController(forRoute: normalized) ?? viewController(forRoute: route) {
            vc.hidesBottomBarWhenPushed = true
            nav.pushViewController(vc, animated: true)
        } else {
            // Fallback: try to route through dashboard's XLForm dispatcher if available
            if let dashVC = dashboardVC as? NSObject,
               dashVC.responds(to: Selector(("pp_routeCommandCenterRoute:"))) {
                // Switch to Pulse tab and forward
                selectedIndex = 0
                // Delay so tab switch completes
                DispatchQueue.main.async {
                    _ = dashVC.perform(Selector(("pp_routeCommandCenterRoute:")), with: route)
                }
            }
        }
    }

    private func viewController(forRoute route: String) -> UIViewController? {
        // Map route tags to concrete view controller class names.
        // Uses NSClassFromString so no hard import dependency is required.
        let mapping: [String: String] = [
            "marketItems": "PPProviderMarketItemsViewController",
            "managePharmacy": "PPPharmacyMedicinesViewController",
            "manageServices": "PPServicesListViewController",
            "vetList": "PPVetsListViewController",
            "__vet": "PPVetsListViewController",
            "veterinary": "PPVetsListViewController",
            "delivery": "PPDeliveryDashboardViewController",
            "deliveryCompany": "PPDeliveryCompanyDashboardViewController",
            "adoptPetsList": "PPAdoptPetsListViewController",
            "fulfillmentOrders": "PPFulfillmentListViewController",
            "notificationsInbox": "NotificationsListViewController",
            "providerSupportChats": "PPProviderSupportChatsViewController",
            "profileSettings": "PPProProfileSettingsViewController",
            "branchesManagement": "PPMarketplaceBranchesViewController",
            "notificationSettings": "NotificationSettingsViewController",
            "deliveryCompanyMembers": "PPDeliveryCompanyMembersViewController",
            "PPProviderSupportChatsViewController": "PPProviderSupportChatsViewController",
        ]
        let className = mapping[route] ?? route
        // Try direct class name first
        if let vcType = NSClassFromString(className) as? UIViewController.Type {
            return vcType.init()
        }
        // Try with module prefix (PurePetsPro)
        if let vcType = NSClassFromString("PurePetsPro.\(className)") as? UIViewController.Type {
            return vcType.init()
        }
        // Unknown route: return nil to allow fallback to dashboard dispatcher
        return nil
    }

    // MARK: UITabBarControllerDelegate

    public func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // Haptics for tab selection
        UISelectionFeedbackGenerator().selectionChanged()
        return true
    }

    public func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        // Pop to root when re-selecting the same tab (UITabBarController standard)
        // UIKit already handles this for the selected nav, but we ensure haptics.
    }
}


// MARK: - Surface-backed tab host
//
// Embeds a store-driven surface owned by the dashboard's
// `PPProCommandCenterSurfaceController`, so a tab lists only what Objective-C
// actually granted.
//
// Reaching the surface: `AdminDashboardViewController` holds it on its private
// `commandCenterSurfaceController` property, installed in that controller's
// `viewDidLoad`. Tab 0 is selected at build time, so the surface exists well
// before another tab can be tapped; the embed is retried on every appearance in
// case of a different ordering. If it is ever unreachable this shows the existing
// locked copy rather than an ungated list — fail closed.
private final class PPProSurfaceTabController: UIViewController {
    var dashboardProvider: (() -> UIViewController?)?
    var makeChild: ((PPProCommandCenterSurfaceController) -> UIViewController)?

    private var embedded: UIViewController?
    private let lockedLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.ppBackground

        lockedLabel.text = Language.get("MenuMap_Locked_Subtitle", alter: nil)
        lockedLabel.textColor = UIColor.ppTextSecondary
        lockedLabel.numberOfLines = 0
        lockedLabel.textAlignment = .center
        lockedLabel.font = UIFontMetrics(forTextStyle: .subheadline)
            .scaledFont(for: Styling.fontRegular(14))
        lockedLabel.adjustsFontForContentSizeCategory = true
        lockedLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lockedLabel)
        NSLayoutConstraint.activate([
            lockedLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            lockedLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            lockedLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        embedIfPossible()
    }

    private func embedIfPossible() {
        guard embedded == nil, let makeChild else { return }
        guard let dashboard = dashboardProvider?() as? NSObject,
              dashboard.responds(to: Selector(("commandCenterSurfaceController"))),
              let surface = dashboard.value(forKey: "commandCenterSurfaceController")
                  as? PPProCommandCenterSurfaceController
        else { return }

        let child = makeChild(surface)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(child)
        view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        child.didMove(toParent: self)
        embedded = child
        lockedLabel.isHidden = true
    }
}


// MARK: - Menu Table (superseded by the surface-backed Menu tab)
//
// Retained rather than deleted per the platform no-removal invariant. It is no
// longer wired to a tab: its entry list is not permission-derived, so using it
// would re-open the gap documented in `buildTabs()`.
private final class PPProMenuTableViewController: UITableViewController {
    var onRoute: ((String) -> Void)?
    private struct Entry { let title: String; let subtitle: String; let route: String; let symbol: String }
    private let entries: [Entry] = [
        Entry(title: Language.get("Market_Title", alter: "Marketplace"), subtitle: Language.get("Market_EmptySubtitle", alter: "Manage items"), route: "marketItems", symbol: "bag.fill"),
        Entry(title: Language.get("Pharmacy_Section_Title", alter: "Pharmacy"), subtitle: Language.get("Pharmacy_Manage_Subtitle", alter: "Medicines"), route: "managePharmacy", symbol: "pills.fill"),
        Entry(title: Language.get("ManageServices", alter: "Services"), subtitle: Language.get("ProviderTypeServiceSubtitle", alter: "Grooming & training"), route: "manageServices", symbol: "scissors"),
        Entry(title: Language.get("ProviderTypeVetTitle", alter: "Veterinary"), subtitle: Language.get("Vet_Manage_Subtitle", alter: "Clinics"), route: "__vet", symbol: "cross.case.fill"),
        Entry(title: Language.get("DeliveryCompany_Title", alter: "Delivery Company"), subtitle: Language.get("DeliveryCompany_DashboardShell_OpenCompanySubtitle", alter: "Fleet"), route: "deliveryCompany", symbol: "truck.box.fill"),
        Entry(title: Language.get("DeliveryManagement", alter: "Delivery"), subtitle: Language.get("DeliveryManagementSubtitle", alter: "Orders to deliver"), route: "delivery", symbol: "shippingbox.fill"),
        Entry(title: Language.get("AdoptPetsTitle", alter: "Adoption"), subtitle: Language.get("AdoptPetsSubtitle", alter: "Adoptable pets"), route: "adoptPetsList", symbol: "heart.fill"),
        Entry(title: Language.get("Fulfillment_Title", alter: "Fulfillment"), subtitle: Language.get("Fulfillment_EmptySubtitle", alter: "Orders to fulfill"), route: "fulfillmentOrders", symbol: "shippingbox.fill"),
        Entry(title: Language.get("NotificationsTitle", alter: "Notifications"), subtitle: Language.get("MenuMap_Notifications_Subtitle", alter: "Inbox"), route: "notificationsInbox", symbol: "bell.badge.fill"),
        Entry(title: Language.get("ch_provider_support_chats_title", alter: "Support Chats"), subtitle: Language.get("ch_provider_support_chats_subtitle", alter: "Messages"), route: "providerSupportChats", symbol: "bubble.left.and.bubble.right.fill"),
    ]
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = UIColor.ppBackground
        tableView.separatorStyle = .none
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 68
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { entries.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let e = entries[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = cell.defaultContentConfiguration()
        cfg.text = e.title
        cfg.secondaryText = e.subtitle
        cfg.image = UIImage(systemName: e.symbol)
        cfg.imageProperties.tintColor = UIColor.ppPrimary
        cell.contentConfiguration = cfg
        cell.backgroundColor = UIColor.ppSurface
        cell.layer.cornerRadius = 18
        cell.layer.cornerCurve = .continuous
        cell.clipsToBounds = true
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onRoute?(entries[indexPath.row].route)
    }
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor.ppSurface
    }
}

// MARK: - More Table (superseded by the surface-backed More tab)
//
// Retained rather than deleted per the no-removal invariant; unwired because its
// entry list is not permission-derived.
private final class PPProMoreTableViewController: UITableViewController {
    var onRoute: ((String) -> Void)?
    var onProfile: (() -> Void)?
    private struct Entry { let title: String; let route: String; let symbol: String }
    private let entries: [Entry] = [
        Entry(title: Language.get("ch_provider_support_chats_title", alter: "Support Chats"), route: "providerSupportChats", symbol: "bubble.left.and.bubble.right.fill"),
        Entry(title: Language.get("Fulfillment_Title", alter: "Fulfillment"), route: "fulfillmentOrders", symbol: "shippingbox.fill"),
        Entry(title: Language.get("MarketplaceBranches_Manage", alter: "Branches"), route: "branchesManagement", symbol: "building.2.fill"),
        Entry(title: Language.get("DeliveryCompany_Tab_Members", alter: "Company Members"), route: "deliveryCompanyMembers", symbol: "person.2.fill"),
        Entry(title: Language.get("NotificationSettings", alter: "Notification Settings"), route: "notificationSettings", symbol: "bell.badge.fill"),
        Entry(title: Language.get("ProfileSettings", alter: "Profile Settings"), route: "profileSettings", symbol: "gearshape.fill"),
    ]
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = UIColor.ppBackground
        tableView.separatorStyle = .none
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 56
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { entries.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let e = entries[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = cell.defaultContentConfiguration()
        cfg.text = e.title
        cfg.image = UIImage(systemName: e.symbol)
        cfg.imageProperties.tintColor = UIColor.ppPrimary
        cell.contentConfiguration = cfg
        cell.backgroundColor = UIColor.ppSurface
        cell.layer.cornerRadius = 18
        cell.layer.cornerCurve = .continuous
        cell.clipsToBounds = true
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let r = entries[indexPath.row].route
        if r == "profileSettings" { onProfile?() } else { onRoute?(r) }
    }
}
