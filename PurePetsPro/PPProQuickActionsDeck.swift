//
//  PPProQuickActionsDeck.swift
//  PurePetsPro
//
//  Reimagined Flagship Quick Actions Command Deck for Pure Pets Pro.
//  Category-defining aerospace & boutique enterprise design.
//

import UIKit

// MARK: - Quick Action Item Data Model

@objc(PPProQuickActionData)
public final class PPProQuickActionData: NSObject {
    @objc public let titleKey: String
    @objc public let subtitleKey: String?
    @objc public let iconName: String
    @objc public let badgeText: String?
    @objc public let isFeatured: Bool
    @objc public let showsBreathingDot: Bool
    @objc public let domainKey: String
    @objc public let handler: (() -> Void)?

    @objc public init(
        titleKey: String,
        subtitleKey: String? = nil,
        iconName: String,
        badgeText: String? = nil,
        isFeatured: Bool = false,
        showsBreathingDot: Bool = false,
        domainKey: String = "general",
        handler: (() -> Void)? = nil
    ) {
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.iconName = iconName
        self.badgeText = badgeText
        self.isFeatured = isFeatured
        self.showsBreathingDot = showsBreathingDot
        self.domainKey = domainKey
        self.handler = handler
        super.init()
    }
}

// MARK: - Quick Action Card View

private final class PPProQuickActionCard: UIControl {
    let item: PPProQuickActionData

    private let containerView = UIView()
    private let backgroundGlassView = UIView()
    private let ambientAuraLayer = CAGradientLayer()

    private let iconShell = UIView()
    private let iconGradientLayer = CAGradientLayer()
    private let iconImageView = UIImageView()

    private let textStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let badgePill = UIView()
    private let badgeLabel = UILabel()
    private let breathingDot = UIView()
    private let breathingDotCore = UIView()

    init(item: PPProQuickActionData) {
        self.item = item
        super.init(frame: .zero)
        setupUI()
        configureData()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ambientAuraLayer.frame = containerView.bounds
        iconGradientLayer.frame = iconShell.bounds
    }

    private func setupUI() {
        backgroundColor = .clear
        clipsToBounds = false

        // Container
        containerView.isUserInteractionEnabled = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = 20.0
        containerView.layer.cornerCurve = .continuous
        containerView.layer.masksToBounds = true
        addSubview(containerView)

        // Glass background
        backgroundGlassView.translatesAutoresizingMaskIntoConstraints = false
        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundGlassView.backgroundColor = isDark
            ? UIColor(white: 0.14, alpha: 0.88)
            : UIColor.white.withAlphaComponent(0.92)
        containerView.addSubview(backgroundGlassView)

        // Ambient Aura
        let palette = domainColors(for: item.domainKey)
        ambientAuraLayer.type = .radial
        ambientAuraLayer.colors = [
            palette.primary.withAlphaComponent(isDark ? 0.16 : 0.08).cgColor,
            UIColor.clear.cgColor
        ]
        ambientAuraLayer.locations = [0.0, 1.0]
        ambientAuraLayer.startPoint = CGPoint(x: 0.15, y: 0.15)
        ambientAuraLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        containerView.layer.addSublayer(ambientAuraLayer)

        // Specular Border
        containerView.layer.borderWidth = 1.0 / UIScreen.main.scale
        containerView.layer.borderColor = isDark
            ? UIColor(white: 1.0, alpha: 0.12).cgColor
            : UIColor(white: 0.0, alpha: 0.08).cgColor

        // Shadow on root control
        layer.shadowColor = palette.primary.cgColor
        layer.shadowOpacity = item.isFeatured ? (isDark ? 0.35 : 0.18) : (isDark ? 0.18 : 0.06)
        layer.shadowRadius = item.isFeatured ? 14.0 : 8.0
        layer.shadowOffset = CGSize(width: 0, height: item.isFeatured ? 6.0 : 3.0)

        // Icon Shell
        iconShell.translatesAutoresizingMaskIntoConstraints = false
        let iconDimension: CGFloat = item.isFeatured ? 42.0 : 36.0
        iconShell.layer.cornerRadius = 12.0
        iconShell.layer.cornerCurve = .continuous
        iconShell.layer.masksToBounds = true
        containerView.addSubview(iconShell)

        iconGradientLayer.colors = [
            palette.primary.cgColor,
            palette.secondary.cgColor
        ]
        iconGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        iconGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        iconShell.layer.addSublayer(iconGradientLayer)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconShell.addSubview(iconImageView)

        // Text Stack
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 2.0
        textStack.alignment = .leading
        textStack.distribution = .fill
        containerView.addSubview(textStack)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = item.isFeatured ? Styling.fontBold(15.5) : Styling.fontBold(14.0)
        titleLabel.textColor = isDark ? .white : UIColor.ppTextPrimary
        titleLabel.numberOfLines = 1
        textStack.addArrangedSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = Styling.fontRegular(11.0)
        subtitleLabel.textColor = isDark ? UIColor(white: 0.72, alpha: 1.0) : UIColor.ppTextSecondary
        subtitleLabel.numberOfLines = item.isFeatured ? 2 : 1
        textStack.addArrangedSubview(subtitleLabel)

        // Badge Pill
        badgePill.translatesAutoresizingMaskIntoConstraints = false
        badgePill.backgroundColor = palette.primary
        badgePill.layer.cornerRadius = 10.0
        badgePill.layer.cornerCurve = .continuous
        badgePill.layer.masksToBounds = true
        badgePill.isHidden = true
        containerView.addSubview(badgePill)

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = Styling.fontBold(10.5)
        badgeLabel.textColor = .white
        badgeLabel.textAlignment = .center
        badgePill.addSubview(badgeLabel)

        // Breathing Dot
        breathingDot.translatesAutoresizingMaskIntoConstraints = false
        breathingDot.layer.cornerRadius = 6.0
        breathingDot.backgroundColor = palette.primary.withAlphaComponent(0.35)
        breathingDot.isHidden = true
        containerView.addSubview(breathingDot)

        breathingDotCore.translatesAutoresizingMaskIntoConstraints = false
        breathingDotCore.layer.cornerRadius = 3.0
        breathingDotCore.backgroundColor = palette.primary
        breathingDot.addSubview(breathingDotCore)

        // Layout Constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            backgroundGlassView.topAnchor.constraint(equalTo: containerView.topAnchor),
            backgroundGlassView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            backgroundGlassView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            backgroundGlassView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            iconShell.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12.0),
            iconShell.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconShell.widthAnchor.constraint(equalToConstant: iconDimension),
            iconShell.heightAnchor.constraint(equalToConstant: iconDimension),

            iconImageView.centerXAnchor.constraint(equalTo: iconShell.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconShell.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: iconDimension * 0.54),
            iconImageView.heightAnchor.constraint(equalToConstant: iconDimension * 0.54),

            textStack.leadingAnchor.constraint(equalTo: iconShell.trailingAnchor, constant: 10.0),
            textStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: badgePill.leadingAnchor, constant: -6.0),

            badgePill.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12.0),
            badgePill.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            badgePill.heightAnchor.constraint(equalToConstant: 20.0),

            badgeLabel.leadingAnchor.constraint(equalTo: badgePill.leadingAnchor, constant: 7.0),
            badgeLabel.trailingAnchor.constraint(equalTo: badgePill.trailingAnchor, constant: -7.0),
            badgeLabel.centerYAnchor.constraint(equalTo: badgePill.centerYAnchor),

            breathingDot.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12.0),
            breathingDot.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            breathingDot.widthAnchor.constraint(equalToConstant: 12.0),
            breathingDot.heightAnchor.constraint(equalToConstant: 12.0),

            breathingDotCore.centerXAnchor.constraint(equalTo: breathingDot.centerXAnchor),
            breathingDotCore.centerYAnchor.constraint(equalTo: breathingDot.centerYAnchor),
            breathingDotCore.widthAnchor.constraint(equalToConstant: 6.0),
            breathingDotCore.heightAnchor.constraint(equalToConstant: 6.0),
        ])

        // Tap Handlers
        addTarget(self, action: #selector(didTouchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(didTouchUp), for: [.touchUpInside, .touchCancel, .touchDragExit])
    }

    private func configureData() {
        titleLabel.text = Language.get(item.titleKey, alter: item.titleKey)

        if let subKey = item.subtitleKey, !subKey.isEmpty {
            subtitleLabel.text = Language.get(subKey, alter: subKey)
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }

        if let image = UIImage(systemName: item.iconName) {
            iconImageView.image = image
        } else if let image = UIImage(named: item.iconName) {
            iconImageView.image = image
        }

        if let badge = item.badgeText, !badge.isEmpty {
            badgeLabel.text = badge
            badgePill.isHidden = false
            breathingDot.isHidden = true
        } else if item.showsBreathingDot {
            badgePill.isHidden = true
            breathingDot.isHidden = false
            startBreathingMotion()
        } else {
            badgePill.isHidden = true
            breathingDot.isHidden = true
        }
    }

    private func startBreathingMotion() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.85
        pulse.toValue = 1.35
        pulse.duration = 1.0
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        breathingDot.layer.add(pulse, forKey: "dot_pulse")

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.4
        opacity.toValue = 0.95
        opacity.duration = 1.0
        opacity.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        opacity.autoreverses = true
        opacity.repeatCount = .infinity
        breathingDot.layer.add(opacity, forKey: "dot_opacity")
    }

    @objc private func didTouchDown() {
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }
    }

    @objc private func didTouchUp() {
        UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.5, options: [.allowUserInteraction]) {
            self.transform = .identity
        }
    }

    private func domainColors(for domain: String) -> (primary: UIColor, secondary: UIColor) {
        switch domain {
        case "fulfillment":
            return (
                primary: UIColor(red: 0.85, green: 0.12, blue: 0.27, alpha: 1.0),
                secondary: UIColor(red: 0.98, green: 0.35, blue: 0.45, alpha: 1.0)
            )
        case "market":
            return (
                primary: UIColor(red: 0.05, green: 0.65, blue: 0.45, alpha: 1.0),
                secondary: UIColor(red: 0.12, green: 0.82, blue: 0.58, alpha: 1.0)
            )
        case "pharmacy":
            return (
                primary: UIColor(red: 0.08, green: 0.52, blue: 0.88, alpha: 1.0),
                secondary: UIColor(red: 0.22, green: 0.74, blue: 0.98, alpha: 1.0)
            )
        case "vets":
            return (
                primary: UIColor(red: 0.92, green: 0.42, blue: 0.12, alpha: 1.0),
                secondary: UIColor(red: 0.98, green: 0.62, blue: 0.22, alpha: 1.0)
            )
        case "delivery":
            return (
                primary: UIColor(red: 0.42, green: 0.35, blue: 0.88, alpha: 1.0),
                secondary: UIColor(red: 0.62, green: 0.48, blue: 0.98, alpha: 1.0)
            )
        case "adoption":
            return (
                primary: UIColor(red: 0.88, green: 0.18, blue: 0.45, alpha: 1.0),
                secondary: UIColor(red: 0.98, green: 0.42, blue: 0.65, alpha: 1.0)
            )
        case "notifications":
            return (
                primary: UIColor(red: 0.10, green: 0.60, blue: 0.72, alpha: 1.0),
                secondary: UIColor(red: 0.25, green: 0.78, blue: 0.88, alpha: 1.0)
            )
        case "active_route":
            return (
        primary: UIColor(red: 0.02, green: 0.72, blue: 0.42, alpha: 1.0),
                secondary: UIColor(red: 0.10, green: 0.90, blue: 0.55, alpha: 1.0)
            )
        default:
            return (
                primary: UIColor.ppPrimary ?? UIColor(red: 0.85, green: 0.12, blue: 0.27, alpha: 1.0),
                secondary: UIColor(red: 0.98, green: 0.35, blue: 0.45, alpha: 1.0)
            )
        }
    }
}

// MARK: - Sovereign Quick Actions Command Deck View

@objc(PPProQuickActionsDeckView)
public final class PPProQuickActionsDeckView: UIView {

    @objc public var actions: [PPProQuickActionData] = [] {
        didSet {
            rebuildGrid()
        }
    }

    @objc public var titleKey: String? {
        didSet { refreshHeaderCopy() }
    }

    @objc public var subtitleKey: String? {
        didSet { refreshHeaderCopy() }
    }

    @objc public var trailingTitleKey: String? {
        didSet { refreshHeaderCopy() }
    }

    @objc public var trailingHandler: (() -> Void)? {
        didSet { refreshHeaderCopy() }
    }

    private let headerStack = UIStackView()
    private let titleLabel = UILabel()
    private let telemetryPill = UIView()
    private let telemetryDot = UIView()
    private let telemetryLabel = UILabel()
    private let trailingButton = UIButton(type: .system)
    private let gridStack = UIStackView()

    private var cardViews: [PPProQuickActionCard] = []
    private var didAnimateEntrance = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupDeck()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDeck()
    }

    private func setupDeck() {
        backgroundColor = .clear

        // Header Stack
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8.0
        headerStack.semanticContentAttribute = Language.isRTL() ? .forceRightToLeft : .forceLeftToRight
        addSubview(headerStack)

        // Section Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Styling.fontBold(18.0)
        titleLabel.textColor = UIColor.ppTextPrimary
        titleLabel.textAlignment = Language.alignmentForCurrentLanguage()
        headerStack.addArrangedSubview(titleLabel)

        // Telemetry Live Signal Pill
        telemetryPill.translatesAutoresizingMaskIntoConstraints = false
        telemetryPill.backgroundColor = (UIColor.ppPrimary ?? .systemPink).withAlphaComponent(0.12)
        telemetryPill.layer.cornerRadius = 10.0
        telemetryPill.layer.cornerCurve = .continuous
        telemetryPill.layer.masksToBounds = true
        headerStack.addArrangedSubview(telemetryPill)

        telemetryDot.translatesAutoresizingMaskIntoConstraints = false
        telemetryDot.backgroundColor = UIColor(red: 0.05, green: 0.72, blue: 0.45, alpha: 1.0)
        telemetryDot.layer.cornerRadius = 3.0
        telemetryPill.addSubview(telemetryDot)

        telemetryLabel.translatesAutoresizingMaskIntoConstraints = false
        telemetryLabel.font = Styling.fontBold(10.5)
        telemetryLabel.textColor = UIColor.ppTextPrimary
        telemetryPill.addSubview(telemetryLabel)

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerStack.addArrangedSubview(spacer)

        // Trailing Action Button
        trailingButton.translatesAutoresizingMaskIntoConstraints = false
        trailingButton.layer.cornerRadius = 14.0
        trailingButton.layer.cornerCurve = .continuous
        trailingButton.layer.borderWidth = 1.0 / UIScreen.main.scale
        let isDark = traitCollection.userInterfaceStyle == .dark
        trailingButton.layer.borderColor = isDark ? UIColor(white: 1.0, alpha: 0.12).cgColor : UIColor(white: 0.0, alpha: 0.08).cgColor
        trailingButton.backgroundColor = isDark ? UIColor(white: 0.20, alpha: 0.40) : UIColor.white.withAlphaComponent(0.60)
        trailingButton.contentEdgeInsets = UIEdgeInsets(top: 5.0, left: 11.0, bottom: 5.0, right: 11.0)
        trailingButton.titleLabel?.font = Styling.fontMedium(12.0)
        trailingButton.setTitleColor(UIColor.ppTextPrimary, for: .normal)
        trailingButton.addTarget(self, action: #selector(didTapTrailingButton), for: .touchUpInside)
        headerStack.addArrangedSubview(trailingButton)

        // Grid Stack
        gridStack.translatesAutoresizingMaskIntoConstraints = false
        gridStack.axis = .vertical
        gridStack.spacing = 10.0
        gridStack.alignment = .fill
        gridStack.distribution = .fill
        gridStack.semanticContentAttribute = Language.isRTL() ? .forceRightToLeft : .forceLeftToRight
        addSubview(gridStack)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerStack.heightAnchor.constraint(equalToConstant: 32.0),

            telemetryPill.heightAnchor.constraint(equalToConstant: 20.0),
            telemetryDot.leadingAnchor.constraint(equalTo: telemetryPill.leadingAnchor, constant: 7.0),
            telemetryDot.centerYAnchor.constraint(equalTo: telemetryPill.centerYAnchor),
            telemetryDot.widthAnchor.constraint(equalToConstant: 6.0),
            telemetryDot.heightAnchor.constraint(equalToConstant: 6.0),

            telemetryLabel.leadingAnchor.constraint(equalTo: telemetryDot.trailingAnchor, constant: 4.0),
            telemetryLabel.trailingAnchor.constraint(equalTo: telemetryPill.trailingAnchor, constant: -7.0),
            telemetryLabel.centerYAnchor.constraint(equalTo: telemetryPill.centerYAnchor),

            gridStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12.0),
            gridStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            gridStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            gridStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        refreshHeaderCopy()
    }

    private func refreshHeaderCopy() {
        titleLabel.text = titleKey.flatMap { Language.get($0, alter: $0) } ?? Language.get("DashboardQuickActions_Title", alter: "الإجراءات السريعة")

        let trailingTitle = trailingTitleKey.flatMap { Language.get($0, alter: $0) }
        let hasTrailing = trailingTitle != nil && !trailingTitle!.isEmpty && trailingHandler != nil
        trailingButton.isHidden = !hasTrailing
        trailingButton.setTitle(trailingTitle, for: .normal)
    }

    private func rebuildGrid() {
        for subview in gridStack.arrangedSubviews {
            gridStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        guard !actions.isEmpty else {
            telemetryPill.isHidden = true
            return
        }

        // Update telemetry badge
        let activeSignals = actions.filter { $0.showsBreathingDot || ($0.badgeText != nil && !($0.badgeText!.isEmpty)) }.count
        if activeSignals > 0 {
            telemetryLabel.text = Language.isRTL() ? "\(activeSignals) إشارة نشطة" : "\(activeSignals) Active"
            telemetryPill.isHidden = false
        } else {
            telemetryLabel.text = Language.isRTL() ? "\(actions.count) مسارات" : "\(actions.count) Routes"
            telemetryPill.isHidden = false
        }

        var remainingActions = actions

        // If there is a featured action (e.g. active delivery trip), give it full width on top
        if let featuredIndex = remainingActions.firstIndex(where: { $0.isFeatured }) {
            let featuredItem = remainingActions.remove(at: featuredIndex)
            let featuredCard = PPProQuickActionCard(item: featuredItem)
            featuredCard.translatesAutoresizingMaskIntoConstraints = false
            featuredCard.heightAnchor.constraint(equalToConstant: 72.0).isActive = true
            featuredCard.addTarget(self, action: #selector(handleCardTap(_:)), for: .touchUpInside)
            gridStack.addArrangedSubview(featuredCard)
        }

        // Build 2-column paired rows
        while !remainingActions.isEmpty {
            let countInRow = min(2, remainingActions.count)
            let rowItems = Array(remainingActions.prefix(countInRow))
            remainingActions.removeFirst(countInRow)

            let rowStack = UIStackView()
            rowStack.translatesAutoresizingMaskIntoConstraints = false
            rowStack.axis = .horizontal
            rowStack.spacing = 10.0
            rowStack.alignment = .fill
            rowStack.distribution = .fillEqually
            rowStack.semanticContentAttribute = Language.isRTL() ? .forceRightToLeft : .forceLeftToRight

            for item in rowItems {
                let card = PPProQuickActionCard(item: item)
                card.translatesAutoresizingMaskIntoConstraints = false
                card.heightAnchor.constraint(equalToConstant: 66.0).isActive = true
                card.addTarget(self, action: #selector(handleCardTap(_:)), for: .touchUpInside)
                rowStack.addArrangedSubview(card)
            }

            // If odd item in last row, pad with empty spacer
            if rowItems.count == 1 {
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.backgroundColor = .clear
                rowStack.addArrangedSubview(spacer)
            }

            gridStack.addArrangedSubview(rowStack)
        }
    }

    @objc private func handleCardTap(_ sender: Any) {
        guard let card = sender as? PPProQuickActionCard else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        card.item.handler?()
    }

    @objc private func didTapTrailingButton() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        trailingHandler?()
    }

    @objc public func animateEntrance() {
        guard !didAnimateEntrance else { return }
        didAnimateEntrance = true

        alpha = 0.0
        transform = CGAffineTransform(translationX: 0, y: 16.0)

        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.4, options: .curveEaseOut) {
            self.alpha = 1.0
            self.transform = .identity
        }
    }
}
