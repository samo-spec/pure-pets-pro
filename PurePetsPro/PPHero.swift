import UIKit

/// Controls how `PPHero` participates in the visual hierarchy.
/// Content surfaces carry a restrained brand atmosphere; action docks stay
/// quieter so the primary button remains the visual focus.
@objc public enum PPHeroVisualRole: Int {
    case content = 0
    case actionDock = 1
}

/// A reusable, Objective-C-compatible flagship hero surface.
/// Content remains owned by the embedding controller; this view owns material,
/// ambient depth, interaction response, and its complete motion lifecycle.
@objc(PPHero)
public final class PPHero: UIView, UIGestureRecognizerDelegate {
    private enum Metrics {
        static let cornerRadius: CGFloat = 32.0
        static let particleCount = 5
        static let maxTouchTilt: CGFloat = 0.009
    }

    /// Pure Pets raspberry from the shared PPDesignTokens bridge.
    @objc public var accentColor: UIColor = UIColor.ppPrimary ?? .systemPink {
        didSet { applyPalette() }
    }

    @objc public var visualRole: PPHeroVisualRole = .content {
        didSet {
            guard visualRole != oldValue else { return }
            applyPalette()
            configureParallax()
            refreshMotionState()
        }
    }

    private let materialView = UIVisualEffectView()
    private let atmosphereView = UIView()
    private let highlightView = UIView()
    private let edgeView = UIView()

    private let surfaceGradient = CAGradientLayer()
    private let auroraA = CAGradientLayer()
    private let auroraB = CAGradientLayer()
    private let auroraC = CAGradientLayer()
    private let vignetteLayer = CAGradientLayer()
    private let specularLayer = CAGradientLayer()
    private let particleLayer = CALayer()
    private var particles: [CAShapeLayer] = []

    private var motionRunning = false
    private var parallaxEffect: UIMotionEffectGroup?
    private lazy var depthGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleDepthGesture(_:)))
        gesture.cancelsTouchesInView = false
        gesture.maximumNumberOfTouches = 1
        gesture.delegate = self
        return gesture
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configure() {
        backgroundColor = .clear
        clipsToBounds = true
        layer.cornerRadius = Metrics.cornerRadius
        layer.cornerCurve = .continuous
        isAccessibilityElement = false

        materialView.isUserInteractionEnabled = false
        materialView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(materialView)

        atmosphereView.isUserInteractionEnabled = false
        atmosphereView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        materialView.contentView.addSubview(atmosphereView)

        [surfaceGradient, auroraA, auroraB, auroraC, vignetteLayer, specularLayer, particleLayer].forEach {
            atmosphereView.layer.addSublayer($0)
        }

        [auroraA, auroraB, auroraC].forEach {
            $0.type = .radial
            // Compact falloff keeps each light source local instead of tinting
            // the entire card.
            $0.locations = [0, 0.30, 1]
        }
        surfaceGradient.locations = [0, 0.54, 1]
        vignetteLayer.type = .radial
        vignetteLayer.locations = [0, 0.74, 1]
        specularLayer.locations = [0, 0.14, 0.38, 1]
        particleLayer.masksToBounds = true

        highlightView.isUserInteractionEnabled = false
        highlightView.backgroundColor = .clear
        highlightView.layer.cornerCurve = .continuous
        highlightView.layer.borderWidth = 1 / max(UIScreen.main.scale, 1)
        addSubview(highlightView)

        edgeView.isUserInteractionEnabled = false
        edgeView.backgroundColor = .clear
        edgeView.layer.cornerCurve = .continuous
        edgeView.layer.borderWidth = 1 / max(UIScreen.main.scale, 1)
        addSubview(edgeView)

        buildParticles()
        addGestureRecognizer(depthGesture)
        configureParallax()
        registerForLifecycle()
        applyPalette()
    }

    private func buildParticles() {
        let points: [CGPoint] = [
            .init(x: 0.16, y: 0.22),
            .init(x: 0.38, y: 0.76),
            .init(x: 0.63, y: 0.28),
            .init(x: 0.79, y: 0.68),
            .init(x: 0.91, y: 0.18)
        ]

        particles = points.prefix(Metrics.particleCount).enumerated().map { index, point in
            let size: CGFloat = index == 0 ? 1.6 : 1.0
            let particle = CAShapeLayer()
            particle.name = "pp.hero.particle.\(index)"
            particle.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            particle.path = UIBezierPath(ovalIn: particle.bounds).cgPath
            particle.setValue(point.x, forKey: "normalizedX")
            particle.setValue(point.y, forKey: "normalizedY")
            particle.opacity = 0
            particleLayer.addSublayer(particle)
            return particle
        }
    }

    private func registerForLifecycle() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleReduceMotionChange), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(handlePowerStateChange), name: .NSProcessInfoPowerStateDidChange, object: nil)
        center.addObserver(self, selector: #selector(handleDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(handleWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc private func handleReduceMotionChange() {
        configureParallax()
        refreshMotionState()
    }

    @objc private func handlePowerStateChange() {
        refreshMotionState()
    }

    @objc private func handleDidBecomeActive() {
        startMotion()
    }

    @objc private func handleWillResignActive() {
        stopMotion()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        materialView.frame = bounds
        atmosphereView.frame = materialView.bounds
        highlightView.frame = bounds.insetBy(dx: 0.5, dy: 0.5)
        edgeView.frame = bounds.insetBy(dx: 1.5, dy: 1.5)
        highlightView.layer.cornerRadius = max(0, layer.cornerRadius - 0.5)
        edgeView.layer.cornerRadius = max(0, layer.cornerRadius - 1.5)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        [surfaceGradient, auroraA, auroraB, auroraC, vignetteLayer, specularLayer, particleLayer].forEach {
            $0.frame = atmosphereView.bounds
            $0.cornerRadius = layer.cornerRadius
            $0.cornerCurve = .continuous
        }
        particles.forEach { particle in
            let x = (particle.value(forKey: "normalizedX") as? CGFloat) ?? 0.5
            let y = (particle.value(forKey: "normalizedY") as? CGFloat) ?? 0.5
            particle.position = CGPoint(x: bounds.width * x, y: bounds.height * y)
        }
        CATransaction.commit()

        if window != nil { startMotion() }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        window == nil ? stopMotion() : startMotion()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection == nil ||
            traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyPalette()
            refreshMotionState()
        }
    }

    @objc public func reapplyPalette() {
        applyPalette()
    }

    private func applyPalette() {
        let traits = traitCollection
        let isDark = traits.userInterfaceStyle == .dark
        let isHighContrast = traits.accessibilityContrast == .high
        let isActionDock = visualRole == .actionDock
        depthGesture.isEnabled = !isActionDock

        func token(_ color: UIColor?, alpha: CGFloat = 1) -> UIColor {
            guard let color = color else { return .clear }
            return color.resolvedColor(with: traits).withAlphaComponent(alpha)
        }

        let brand = accentColor.resolvedColor(with: traits)

        // MARK: - Studio master palette

        let canvasTop: UIColor
        let canvasMiddle: UIColor
        let canvasBottom: UIColor

        let auroraBrand: UIColor
        let auroraCool: UIColor
        let auroraWarm: UIColor

        if isDark {
            // Ink, graphite and a trace of black cherry. Alpha is deliberate:
            // the system material must remain visible beneath the color wash.
            canvasTop = token(UIColor.ppSurface, alpha: isActionDock ? 0.76 : 0.88)
            canvasMiddle = token(UIColor.ppBackground, alpha: isActionDock ? 0.72 : 0.84)
            canvasBottom = token(UIColor.ppMineralBeige, alpha: isActionDock ? 0.74 : 0.86)

            auroraBrand = brand
            auroraCool = token(UIColor.ppQuickActionServices)
            auroraWarm = token(UIColor.ppPremiumAccent)
        } else {
            // Porcelain and mineral white. There is no gray endpoint, which is
            // what previously made the lower half look dirty.
            canvasTop = token(UIColor.ppElevatedSurface, alpha: isActionDock ? 0.74 : 0.88)
            canvasMiddle = token(UIColor.ppSurface, alpha: isActionDock ? 0.70 : 0.84)
            canvasBottom = token(UIColor.ppWarmPorcelain, alpha: isActionDock ? 0.72 : 0.82)

            auroraBrand = brand
            auroraCool = token(UIColor.ppQuickActionServices)
            auroraWarm = token(UIColor.ppPremiumAccent)
        }

        // MARK: - Material

        materialView.effect = UIBlurEffect(
            style: isDark
                ? .systemThinMaterialDark
                : .systemThinMaterialLight
        )

        // MARK: - Main surface

        surfaceGradient.colors = [
            canvasTop.cgColor,
            canvasMiddle.cgColor,
            canvasBottom.cgColor
        ]

        surfaceGradient.locations = [0.0, 0.54, 1.0]
        surfaceGradient.startPoint = CGPoint(x: 0.04, y: 0.0)
        surfaceGradient.endPoint = CGPoint(x: 0.96, y: 1.0)

        // MARK: - Aurora lighting

        configureAurora(
            auroraA,
            color: auroraBrand,
            opacity: isActionDock ? (isDark ? 0.040 : 0.018) : (isDark ? 0.120 : 0.045),
            start: CGPoint(x: 0.08, y: 0.10),
            end: CGPoint(x: 0.34, y: 0.38)
        )

        configureAurora(
            auroraB,
            color: auroraCool,
            opacity: isActionDock ? (isDark ? 0.025 : 0.014) : (isDark ? 0.085 : 0.060),
            start: CGPoint(x: 0.92, y: 0.06),
            end: CGPoint(x: 0.60, y: 0.38)
        )

        configureAurora(
            auroraC,
            color: auroraWarm,
            opacity: isActionDock ? 0.0 : (isDark ? 0.035 : 0.018),
            start: CGPoint(x: 0.82, y: 0.96),
            end: CGPoint(x: 0.58, y: 0.72)
        )

        // MARK: - Cinematic depth

        vignetteLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.18).cgColor
        ]

        vignetteLayer.locations = [0.0, 0.78, 1.0]
        vignetteLayer.startPoint = CGPoint(x: 0.50, y: 0.44)
        vignetteLayer.endPoint = CGPoint(x: 1.04, y: 1.04)
        vignetteLayer.opacity = isDark && !isActionDock ? 1 : 0

        // MARK: - Glass specular reflection

        specularLayer.colors = [
            UIColor.white.withAlphaComponent(
                isDark ? 0.12 : (isActionDock ? 0.24 : 0.34)
            ).cgColor,
            UIColor.white.withAlphaComponent(
                isDark ? 0.025 : (isActionDock ? 0.045 : 0.075)
            ).cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor
        ]

        specularLayer.locations = [0.0, 0.12, 0.36, 1.0]
        specularLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        specularLayer.endPoint = CGPoint(x: 0.82, y: 0.74)

        // MARK: - Precision edges

        let highlightAlpha: CGFloat = isHighContrast
            ? 0.82
            : (isDark ? 0.14 : 0.80)

        let edgeAlpha: CGFloat = isHighContrast
            ? (isDark ? 0.34 : 0.30)
            : (isDark ? 0.12 : 0.15)

        highlightView.layer.borderColor =
            UIColor.white.withAlphaComponent(highlightAlpha).cgColor

        edgeView.layer.borderColor = isDark
            ? UIColor.white.withAlphaComponent(edgeAlpha).cgColor
            : token(UIColor.ppQuickActionServices, alpha: edgeAlpha).cgColor

        // MARK: - Premium particles

        particleLayer.isHidden = isActionDock || !isDark

        particles.enumerated().forEach { index, particle in
            particle.fillColor = UIColor.white.cgColor
            particle.opacity = (!isActionDock && isDark)
                ? (index == 0 ? 0.10 : 0.045)
                : 0
            particle.shadowColor = UIColor.white.cgColor
            particle.shadowOpacity = (!isActionDock && isDark) ? 0.10 : 0
            particle.shadowRadius = 1.5
            particle.shadowOffset = .zero
        }
    }

    private func configureAurora(_ layer: CAGradientLayer, color: UIColor, opacity: Float,
                                 start: CGPoint, end: CGPoint) {
        layer.colors = [color.withAlphaComponent(0.92).cgColor,
                        color.withAlphaComponent(0.26).cgColor,
                        UIColor.clear.cgColor]
        layer.startPoint = start
        layer.endPoint = end
        layer.opacity = opacity
    }

    private var shouldAnimate: Bool {
        visualRole == .content && window != nil &&
            UIApplication.shared.applicationState == .active &&
            !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    @objc public func startMotion() {
        guard shouldAnimate, !motionRunning, !bounds.isEmpty else {
            if !shouldAnimate { applyStaticMotionState() }
            return
        }
        motionRunning = true
        animateAurora(auroraA, key: "pp.hero.aurora.a", duration: 24.0,
                      translation: CGPoint(x: 5, y: 3), scale: 1.025)
        animateAurora(auroraB, key: "pp.hero.aurora.b", duration: 28.0,
                      translation: CGPoint(x: -4, y: 5), scale: 1.020)
        animateAurora(auroraC, key: "pp.hero.aurora.c", duration: 32.0,
                      translation: CGPoint(x: 3, y: -3), scale: 1.025)

        guard !particleLayer.isHidden else { return }

        particles.enumerated().forEach { index, particle in
            let animation = CAKeyframeAnimation(keyPath: "transform.translation")
            let dx: CGFloat = index.isMultiple(of: 2) ? 1.5 : -1.2
            let dy: CGFloat = index.isMultiple(of: 3) ? -1.4 : 1.0
            animation.values = [NSValue(cgPoint: .zero), NSValue(cgPoint: CGPoint(x: dx, y: dy)), NSValue(cgPoint: .zero)]
            animation.keyTimes = [0, 0.52, 1]
            animation.duration = 14.0 + Double(index % 5) * 1.8
            animation.beginTime = CACurrentMediaTime() + Double(index) * 0.16
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            particle.add(animation, forKey: "pp.hero.particle.drift")

            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = particle.opacity * 0.58
            opacity.toValue = min(0.14, particle.opacity + 0.025)
            opacity.duration = 7.0 + Double(index % 4)
            opacity.autoreverses = true
            opacity.repeatCount = .infinity
            opacity.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            particle.add(opacity, forKey: "pp.hero.particle.breathe")
        }
    }

    private func animateAurora(_ layer: CALayer, key: String, duration: CFTimeInterval,
                               translation: CGPoint, scale: CGFloat) {
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = [
            NSValue(caTransform3D: CATransform3DIdentity),
            NSValue(caTransform3D: CATransform3DTranslate(CATransform3DMakeScale(scale, scale, 1), translation.x, translation.y, 0)),
            NSValue(caTransform3D: CATransform3DIdentity)
        ]
        animation.keyTimes = [0, 0.5, 1]
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: key)
    }

    @objc public func stopMotion() {
        guard motionRunning else { return }
        motionRunning = false
        [auroraA, auroraB, auroraC].forEach { $0.removeAllAnimations() }
        particles.forEach { $0.removeAllAnimations() }
        resetDepth(animated: false)
    }

    private func refreshMotionState() {
        stopMotion()
        shouldAnimate ? startMotion() : applyStaticMotionState()
    }

    private func applyStaticMotionState() {
        [auroraA, auroraB, auroraC].forEach { $0.removeAllAnimations() }
        particles.forEach { $0.removeAllAnimations() }
        resetDepth(animated: false)
    }

    private func configureParallax() {
        if let currentParallaxEffect = parallaxEffect {
            atmosphereView.removeMotionEffect(currentParallaxEffect)
            self.parallaxEffect = nil
        }

        guard visualRole == .content,
              !UIAccessibility.isReduceMotionEnabled else { return }

        let horizontal = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        horizontal.minimumRelativeValue = -1.5
        horizontal.maximumRelativeValue = 1.5
        let vertical = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        vertical.minimumRelativeValue = -1.0
        vertical.maximumRelativeValue = 1.0
        let group = UIMotionEffectGroup()
        group.motionEffects = [horizontal, vertical]
        atmosphereView.addMotionEffect(group)
        parallaxEffect = group
    }

    @objc private func handleDepthGesture(_ gesture: UIPanGestureRecognizer) {
        guard visualRole == .content,
              !UIAccessibility.isReduceMotionEnabled else { return }
        switch gesture.state {
        case .began, .changed:
            let location = gesture.location(in: self)
            guard bounds.width > 0, bounds.height > 0 else { return }
            let x = min(1, max(-1, ((location.x / bounds.width) - 0.5) * 2))
            let y = min(1, max(-1, ((location.y / bounds.height) - 0.5) * 2))
            var transform = CATransform3DIdentity
            transform.m34 = -1 / 900
            transform = CATransform3DRotate(transform, -y * Metrics.maxTouchTilt, 1, 0, 0)
            transform = CATransform3DRotate(transform, x * Metrics.maxTouchTilt, 0, 1, 0)
            transform = CATransform3DScale(transform, 0.997, 0.997, 1)
            layer.transform = transform
            atmosphereView.transform = CGAffineTransform(translationX: x * 1.4, y: y * 1.0)
        case .ended, .cancelled, .failed:
            resetDepth(animated: true)
        default:
            break
        }
    }

    private func resetDepth(animated: Bool) {
        let changes = {
            self.layer.transform = CATransform3DIdentity
            self.atmosphereView.transform = .identity
        }
        guard animated else { changes(); return }
        let animator = UIViewPropertyAnimator(duration: 0.42, dampingRatio: 0.86, animations: changes)
        animator.startAnimation()
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
