import UIKit

/// A reusable, Objective-C-compatible flagship hero surface.
/// Content remains owned by the embedding controller; this view owns material,
/// ambient depth, interaction response, and its complete motion lifecycle.
@objc(PPHero)
public final class PPHero: UIView, UIGestureRecognizerDelegate {
    private enum Metrics {
        static let cornerRadius: CGFloat = 32.0
        static let particleCount = 14
        static let maxTouchTilt: CGFloat = 0.018
    }

    @objc public var accentColor: UIColor = .systemTeal {
        didSet { applyPalette() }
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
            $0.locations = [0, 0.48, 1]
        }
        surfaceGradient.locations = [0, 0.42, 1]
        vignetteLayer.type = .radial
        vignetteLayer.locations = [0, 0.66, 1]
        specularLayer.locations = [0, 0.22, 0.55, 1]
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
            .init(x: 0.08, y: 0.21), .init(x: 0.17, y: 0.72),
            .init(x: 0.26, y: 0.43), .init(x: 0.36, y: 0.15),
            .init(x: 0.43, y: 0.82), .init(x: 0.51, y: 0.34),
            .init(x: 0.59, y: 0.63), .init(x: 0.67, y: 0.19),
            .init(x: 0.74, y: 0.76), .init(x: 0.82, y: 0.42),
            .init(x: 0.91, y: 0.14), .init(x: 0.94, y: 0.69),
            .init(x: 0.31, y: 0.61), .init(x: 0.71, y: 0.48)
        ]

        particles = points.prefix(Metrics.particleCount).enumerated().map { index, point in
            let size: CGFloat = index.isMultiple(of: 4) ? 2.6 : (index.isMultiple(of: 3) ? 1.8 : 1.25)
            let particle = CAShapeLayer()
            particle.name = "pp.hero.particle.\(index)"
            particle.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            particle.path = UIBezierPath(ovalIn: particle.bounds).cgPath
            particle.setValue(point.x, forKey: "normalizedX")
            particle.setValue(point.y, forKey: "normalizedY")
            particle.opacity = index.isMultiple(of: 4) ? 0.64 : 0.34
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
        }
    }

    @objc public func reapplyPalette() {
        applyPalette()
    }

    private func applyPalette() {
        let dark = traitCollection.userInterfaceStyle == .dark
        let highContrast = traitCollection.accessibilityContrast == .high
        let base = dark ? UIColor(red: 0.035, green: 0.043, blue: 0.052, alpha: 1) :
            UIColor(red: 0.975, green: 0.978, blue: 0.972, alpha: 1)
        let tail = dark ? UIColor(red: 0.065, green: 0.073, blue: 0.086, alpha: 1) :
            UIColor(red: 0.925, green: 0.942, blue: 0.938, alpha: 1)
        let warm = dark ? UIColor(red: 0.13, green: 0.10, blue: 0.16, alpha: 1) :
            UIColor(red: 1.0, green: 0.91, blue: 0.78, alpha: 1)
        let cool = dark ? UIColor(red: 0.04, green: 0.18, blue: 0.20, alpha: 1) :
            UIColor(red: 0.63, green: 0.87, blue: 0.88, alpha: 1)
        let accent = accentColor.resolvedColor(with: traitCollection)

        materialView.effect = UIBlurEffect(style: dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
        surfaceGradient.colors = [base.cgColor, base.mixed(with: tail, amount: 0.36).cgColor, tail.cgColor]
        surfaceGradient.startPoint = CGPoint(x: 0.04, y: 0)
        surfaceGradient.endPoint = CGPoint(x: 0.96, y: 1)

        configureAurora(auroraA, color: accent, opacity: dark ? 0.16 : 0.11,
                        start: CGPoint(x: 0.12, y: 0.16), end: CGPoint(x: 0.66, y: 0.74))
        configureAurora(auroraB, color: cool, opacity: dark ? 0.16 : 0.13,
                        start: CGPoint(x: 0.82, y: 0.20), end: CGPoint(x: 0.34, y: 0.86))
        configureAurora(auroraC, color: warm, opacity: dark ? 0.10 : 0.12,
                        start: CGPoint(x: 0.58, y: 0.88), end: CGPoint(x: 0.18, y: 0.30))

        vignetteLayer.colors = [UIColor.clear.cgColor,
                                UIColor.clear.cgColor,
                                UIColor.black.withAlphaComponent(dark ? 0.22 : 0.07).cgColor]
        vignetteLayer.startPoint = CGPoint(x: 0.48, y: 0.40)
        vignetteLayer.endPoint = CGPoint(x: 1.12, y: 1.04)

        specularLayer.colors = [
            UIColor.white.withAlphaComponent(dark ? 0.12 : 0.50).cgColor,
            UIColor.white.withAlphaComponent(dark ? 0.035 : 0.15).cgColor,
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(dark ? 0.018 : 0.08).cgColor
        ]
        specularLayer.startPoint = CGPoint(x: 0, y: 0)
        specularLayer.endPoint = CGPoint(x: 1, y: 1)

        highlightView.layer.borderColor = UIColor.white.withAlphaComponent(highContrast ? 0.54 : (dark ? 0.16 : 0.70)).cgColor
        edgeView.layer.borderColor = accent.withAlphaComponent(highContrast ? 0.26 : (dark ? 0.10 : 0.055)).cgColor
        particles.forEach { particle in
            particle.fillColor = UIColor.white.withAlphaComponent(dark ? 0.58 : 0.74).cgColor
            particle.shadowColor = accent.cgColor
            particle.shadowOpacity = dark ? 0.24 : 0.12
            particle.shadowRadius = 2.5
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
        window != nil && UIApplication.shared.applicationState == .active &&
            !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    @objc public func startMotion() {
        guard shouldAnimate, !motionRunning, !bounds.isEmpty else {
            if !shouldAnimate { applyStaticMotionState() }
            return
        }
        motionRunning = true
        animateAurora(auroraA, key: "pp.hero.aurora.a", duration: 16.0,
                      translation: CGPoint(x: 18, y: 10), scale: 1.08)
        animateAurora(auroraB, key: "pp.hero.aurora.b", duration: 19.0,
                      translation: CGPoint(x: -14, y: 16), scale: 1.06)
        animateAurora(auroraC, key: "pp.hero.aurora.c", duration: 22.0,
                      translation: CGPoint(x: 12, y: -10), scale: 1.10)

        particles.enumerated().forEach { index, particle in
            let animation = CAKeyframeAnimation(keyPath: "transform.translation")
            let dx: CGFloat = index.isMultiple(of: 2) ? 4.5 : -3.5
            let dy: CGFloat = index.isMultiple(of: 3) ? -4 : 3
            animation.values = [NSValue(cgPoint: .zero), NSValue(cgPoint: CGPoint(x: dx, y: dy)), NSValue(cgPoint: .zero)]
            animation.keyTimes = [0, 0.52, 1]
            animation.duration = 8.5 + Double(index % 5) * 1.35
            animation.beginTime = CACurrentMediaTime() + Double(index) * 0.16
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            particle.add(animation, forKey: "pp.hero.particle.drift")

            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = particle.opacity * 0.58
            opacity.toValue = min(0.78, particle.opacity + 0.14)
            opacity.duration = 4.8 + Double(index % 4)
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
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let horizontal = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        horizontal.minimumRelativeValue = -4
        horizontal.maximumRelativeValue = 4
        let vertical = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        vertical.minimumRelativeValue = -3
        vertical.maximumRelativeValue = 3
        let group = UIMotionEffectGroup()
        group.motionEffects = [horizontal, vertical]
        atmosphereView.addMotionEffect(group)
    }

    @objc private func handleDepthGesture(_ gesture: UIPanGestureRecognizer) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
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
            atmosphereView.transform = CGAffineTransform(translationX: x * 3.5, y: y * 2.5)
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

private extension UIColor {
    func mixed(with color: UIColor, amount: CGFloat) -> UIColor {
        let amount = min(1, max(0, amount))
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else { return self }
        return UIColor(red: r1 + (r2 - r1) * amount,
                       green: g1 + (g2 - g1) * amount,
                       blue: b1 + (b2 - b1) * amount,
                       alpha: a1 + (a2 - a1) * amount)
    }
}
