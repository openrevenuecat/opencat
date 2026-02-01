import SwiftUI
import UIKit

// MARK: - CALayer Extension for Filters (From Telegram)

extension CALayer {
    /// Creates a luminanceToAlpha filter (used for masking)
    static func luminanceToAlpha() -> NSObject? {
        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else { return nil }
        let filter = filterClass.perform(NSSelectorFromString("filterWithName:"), with: "luminanceToAlpha")?.takeUnretainedValue() as? NSObject
        return filter
    }

    /// Creates a colorMatrix filter
    static func colorMatrix(matrix: [Float]) -> NSObject? {
        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else { return nil }
        guard let filter = filterClass.perform(NSSelectorFromString("filterWithName:"), with: "colorMatrix")?.takeUnretainedValue() as? NSObject else { return nil }

        var matrixValues = matrix
        let value = NSValue(bytes: &matrixValues, objCType: "{CAColorMatrix=ffffffffffffffffffff}")
        filter.setValue(value, forKey: "inputColorMatrix")

        return filter
    }
}

// MARK: - Color Matrices (From Telegram's RestingBackgroundView)

struct GlassColorMatrix {
    /// Light mode color matrix - increases vibrancy
    static let light: [Float] = [
        1.185, -0.05, -0.005, 0.0, -0.2,
        -0.015, 1.15, -0.005, 0.0, -0.2,
        -0.015, -0.05, 1.195, 0.0, -0.2,
        0.0, 0.0, 0.0, 1.0, 0.0
    ]

    /// Dark mode color matrix
    static let dark: [Float] = [
        1.082, -0.113, -0.011, 0.0, 0.135,
        -0.034, 1.003, -0.011, 0.0, 0.135,
        -0.034, -0.113, 1.105, 0.0, 0.135,
        0.0, 0.0, 0.0, 1.0, 0.0
    ]
}

// MARK: - Complete Liquid Glass View

public final class LiquidGlassView: UIView {

    // MARK: - Constants

    private enum Constants {
        static let blurRadius: CGFloat = 8.0  // Telegram's blur radius
        static let shadowInset: CGFloat = 32.0
        static let springDamping: CGFloat = 0.7
        static let springResponse: CGFloat = 0.4
    }

    // MARK: - Subviews

    private let effectView: UIVisualEffectView
    private let shadowImageView: UIImageView
    private let foregroundImageView: UIImageView
    private let tintOverlayView: UIView
    private let selectionView: UIView?  // For tab selection highlight

    // MARK: - State

    private var currentCornerRadius: CGFloat = 20
    private var currentIsDark: Bool = false
    private var currentTintColor: UIColor = .white.withAlphaComponent(0.6)
    private var colorMatrixApplied: Bool = false

    // Selection state (for tab bar style)
    private var selectionFrame: CGRect = .zero
    private var isSelectionVisible: Bool = false

    // MARK: - Init

    public override init(frame: CGRect) {
        // Effect view with blur
        self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))

        // Shadow
        self.shadowImageView = UIImageView()
        self.shadowImageView.contentMode = .scaleToFill

        // Foreground highlights
        self.foregroundImageView = UIImageView()
        self.foregroundImageView.contentMode = .scaleToFill

        // Tint
        self.tintOverlayView = UIView()

        // Selection indicator
        self.selectionView = UIView()

        super.init(frame: frame)

        backgroundColor = .clear
        clipsToBounds = false

        setupBlurView()
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupBlurView() {
        // Hide default visual effect subview (like Telegram)
        for subview in effectView.subviews {
            if subview.description.contains("VisualEffectSubview") {
                subview.isHidden = true
            }
        }

        // Configure blur filters
        guard let sublayer = effectView.layer.sublayers?.first,
              let filters = sublayer.filters else { return }

        sublayer.backgroundColor = nil
        sublayer.isOpaque = false

        // Keep only gaussianBlur and colorSaturate (like Telegram)
        let allowedFilterNames = ["gaussianBlur", "colorSaturate"]

        sublayer.filters = filters.compactMap { filter -> Any? in
            guard let filter = filter as? NSObject else { return filter }
            let filterName = String(describing: filter)

            guard allowedFilterNames.contains(filterName) else { return nil }

            // Set custom blur radius
            if filterName == "gaussianBlur" {
                filter.setValue(Constants.blurRadius as NSNumber, forKey: "inputRadius")
            }

            return filter
        }
    }

    private func setupSubviews() {
        addSubview(shadowImageView)
        addSubview(effectView)
        addSubview(tintOverlayView)
        addSubview(foregroundImageView)

        if let selectionView = selectionView {
            selectionView.backgroundColor = .white.withAlphaComponent(0.1)
            selectionView.isHidden = true
            addSubview(selectionView)
        }
    }

    // MARK: - Update

    public func update(
        size: CGSize,
        cornerRadius: CGFloat,
        isDark: Bool,
        tintColor: UIColor = .white.withAlphaComponent(0.6),
        animated: Bool = false
    ) {
        self.currentCornerRadius = cornerRadius
        self.currentIsDark = isDark
        self.currentTintColor = tintColor

        let updateBlock = {
            self.updateLayout(size: size, cornerRadius: cornerRadius)
            self.updateColorMatrix(isDark: isDark)
            self.updateTint(tintColor: tintColor, isDark: isDark, cornerRadius: cornerRadius)
            self.updateImages(size: size, cornerRadius: cornerRadius, isDark: isDark, tintColor: tintColor)
        }

        if animated {
            UIView.animate(
                withDuration: 0.35,
                delay: 0,
                usingSpringWithDamping: Constants.springDamping,
                initialSpringVelocity: 0,
                options: [.allowUserInteraction],
                animations: updateBlock
            )
        } else {
            updateBlock()
        }
    }

    private func updateLayout(size: CGSize, cornerRadius: CGFloat) {
        let bounds = CGRect(origin: .zero, size: size)

        effectView.frame = bounds
        effectView.layer.cornerRadius = cornerRadius
        effectView.layer.cornerCurve = .continuous
        effectView.clipsToBounds = true

        tintOverlayView.frame = bounds
        tintOverlayView.layer.cornerRadius = cornerRadius
        tintOverlayView.layer.cornerCurve = .continuous
        tintOverlayView.clipsToBounds = true

        foregroundImageView.frame = bounds
        foregroundImageView.layer.cornerRadius = cornerRadius
        foregroundImageView.layer.cornerCurve = .continuous
        foregroundImageView.clipsToBounds = true

        // Shadow extends beyond bounds
        let shadowFrame = bounds.insetBy(dx: -Constants.shadowInset, dy: -Constants.shadowInset)
        shadowImageView.frame = shadowFrame
    }

    private func updateColorMatrix(isDark: Bool) {
        guard let sublayer = effectView.layer.sublayers?.first else { return }

        // Apply color matrix filter (like Telegram's RestingBackgroundView)
        let matrix = isDark ? GlassColorMatrix.dark : GlassColorMatrix.light

        if let colorMatrixFilter = CALayer.colorMatrix(matrix: matrix) {
            // Find existing filters and add/replace color matrix
            var newFilters: [Any] = sublayer.filters ?? []

            // Remove existing color matrix if any
            newFilters = newFilters.filter { filter in
                guard let filter = filter as? NSObject else { return true }
                return String(describing: filter) != "colorMatrix"
            }

            newFilters.append(colorMatrixFilter)
            sublayer.filters = newFilters
            sublayer.setValue(1.0, forKey: "scale")
        }

        colorMatrixApplied = true
    }

    private func updateTint(tintColor: UIColor, isDark: Bool, cornerRadius: CGFloat) {
        tintOverlayView.backgroundColor = tintColor.withAlphaComponent(isDark ? 0.08 : 0.1)
    }

    private func updateImages(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tintColor: UIColor) {
        // Generate shadow image
        shadowImageView.image = Self.generateShadowImage(
            innerSize: size,
            inset: Constants.shadowInset,
            cornerRadius: cornerRadius
        )

        // Generate foreground (edge highlights)
        foregroundImageView.image = Self.generateForegroundImage(
            size: size,
            cornerRadius: cornerRadius,
            isDark: isDark,
            tintColor: tintColor
        )
    }

    // MARK: - Selection (For Tab Bar Style)

    public func updateSelection(frame: CGRect, visible: Bool, animated: Bool = true) {
        guard let selectionView = selectionView else { return }

        self.selectionFrame = frame
        self.isSelectionVisible = visible

        let updateBlock = {
            selectionView.frame = frame
            selectionView.layer.cornerRadius = min(frame.width, frame.height) / 2
            selectionView.alpha = visible ? 1.0 : 0.0
            selectionView.isHidden = !visible
        }

        if animated {
            // Spring animation like Telegram's LiquidLensView
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                usingSpringWithDamping: 0.65,
                initialSpringVelocity: 0.8,
                options: [.allowUserInteraction],
                animations: updateBlock
            )
        } else {
            updateBlock()
        }
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        update(size: bounds.size, cornerRadius: currentCornerRadius, isDark: currentIsDark, tintColor: currentTintColor)
    }

    // MARK: - Image Generation

    private static func generateShadowImage(innerSize: CGSize, inset: CGFloat, cornerRadius: CGFloat) -> UIImage? {
        let size = CGSize(width: innerSize.width + inset * 2, height: innerSize.height + inset * 2)
        guard size.width > 0, size.height > 0 else { return nil }

        return UIGraphicsImageRenderer(size: size).image { ctx in
            let context = ctx.cgContext
            context.clear(CGRect(origin: .zero, size: size))

            let innerRect = CGRect(x: inset, y: inset, width: innerSize.width, height: innerSize.height)
            let path = UIBezierPath(roundedRect: innerRect, cornerRadius: cornerRadius)

            // Multiple shadow layers (like Telegram)
            let shadowConfigs: [(offset: CGSize, blur: CGFloat, alpha: CGFloat)] = [
                (CGSize(width: 0, height: 1), 40, 0.04),
                (.zero, 10, 0.06),
                (.zero, 20, 0.06)
            ]

            for config in shadowConfigs {
                context.saveGState()
                context.setShadow(
                    offset: config.offset,
                    blur: config.blur,
                    color: UIColor.black.withAlphaComponent(config.alpha).cgColor
                )
                context.setFillColor(UIColor.black.cgColor)
                context.addPath(path.cgPath)
                context.fillPath()
                context.restoreGState()
            }

            // Clear inner area
            context.setBlendMode(.clear)
            context.addPath(path.cgPath)
            context.fillPath()
        }
    }

    private static func generateForegroundImage(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tintColor: UIColor) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }

        return UIGraphicsImageRenderer(size: size).image { ctx in
            let context = ctx.cgContext
            context.clear(CGRect(origin: .zero, size: size))

            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

            // Subtle fill
            context.setFillColor(tintColor.withAlphaComponent(0.03).cgColor)
            context.addPath(path.cgPath)
            context.fillPath()

            // Inner shadows for depth
            let innerShadowBlur: CGFloat = 24.0
            let lightAlpha: CGFloat = isDark ? 0.0 : 0.035
            let darkAlpha: CGFloat = isDark ? 0.0 : 0.035

            // Top-left light shadow
            context.saveGState()
            context.addPath(path.cgPath)
            context.clip()

            let outerRect = rect.insetBy(dx: -100, dy: -100)
            context.addRect(outerRect)
            context.addPath(path.cgPath)
            context.setShadow(offset: CGSize(width: -10, height: 10), blur: innerShadowBlur, color: UIColor.white.withAlphaComponent(lightAlpha).cgColor)
            context.setFillColor(UIColor.black.cgColor)
            context.fillPath(using: .evenOdd)
            context.restoreGState()

            // Bottom-right dark shadow
            context.saveGState()
            context.addPath(path.cgPath)
            context.clip()

            context.addRect(outerRect)
            context.addPath(path.cgPath)
            context.setShadow(offset: CGSize(width: 10, height: -10), blur: innerShadowBlur, color: UIColor.black.withAlphaComponent(darkAlpha).cgColor)
            context.setFillColor(UIColor.black.cgColor)
            context.fillPath(using: .evenOdd)
            context.restoreGState()

            // Edge highlights (gradient stroke)
            let lineWidth: CGFloat = isDark ? 0.5 : 1.0
            let maxAlpha: CGFloat = isDark ? 0.25 : 0.7
            let maxColor = UIColor.white.withAlphaComponent(maxAlpha)
            let minColor = UIColor.white.withAlphaComponent(0.0)

            context.setLineWidth(lineWidth)

            // Left edge gradient
            context.saveGState()
            context.addRect(CGRect(x: 0, y: 0, width: size.width * 0.5, height: size.height))
            context.clip()

            context.addPath(path.cgPath)
            context.replacePathWithStrokedPath()
            context.clip()

            var locations: [CGFloat] = [0.0, 0.5, 0.7, 0.9, 1.0]
            let leftColors = [maxColor, maxColor, minColor, minColor, maxColor].map { $0.cgColor }

            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: leftColors as CFArray, locations: &locations) {
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            context.restoreGState()

            // Right edge gradient
            context.saveGState()
            context.addRect(CGRect(x: size.width * 0.5, y: 0, width: size.width * 0.5, height: size.height))
            context.clip()

            context.addPath(path.cgPath)
            context.replacePathWithStrokedPath()
            context.clip()

            var rightLocations: [CGFloat] = [0.0, 0.1, 0.3, 0.5, 1.0]
            let rightColors = [maxColor, minColor, minColor, maxColor, maxColor].map { $0.cgColor }

            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: rightColors as CFArray, locations: &rightLocations) {
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            context.restoreGState()
        }
    }
}

// MARK: - SwiftUI Integration

struct LiquidGlassBackgroundView: UIViewRepresentable {
    let size: CGSize
    let cornerRadius: CGFloat
    let isDark: Bool
    let tintColor: Color

    func makeUIView(context: Context) -> LiquidGlassView {
        let view = LiquidGlassView()
        view.update(size: size, cornerRadius: cornerRadius, isDark: isDark, tintColor: UIColor(tintColor))
        return view
    }

    func updateUIView(_ uiView: LiquidGlassView, context: Context) {
        uiView.frame = CGRect(origin: .zero, size: size)
        uiView.update(size: size, cornerRadius: cornerRadius, isDark: isDark, tintColor: UIColor(tintColor), animated: true)
    }
}

struct LiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tintColor: Color
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    LiquidGlassBackgroundView(
                        size: geo.size,
                        cornerRadius: cornerRadius,
                        isDark: colorScheme == .dark,
                        tintColor: tintColor
                    )
                }
            )
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 20, tintColor: Color = .white.opacity(0.6)) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, tintColor: tintColor))
    }
}

// MARK: - Telegram-Style Tab Bar Item

struct TabBarItem {
    let icon: String
    let title: String
    var badge: Int = 0
}

// MARK: - Interactive Tab Bar with Selection

struct LiquidGlassTabBar: UIViewRepresentable {
    let items: [TabBarItem]
    @Binding var selectedIndex: Int
    let isDark: Bool

    func makeUIView(context: Context) -> LiquidGlassTabBarView {
        let view = LiquidGlassTabBarView(items: items)
        view.onSelect = { index in
            selectedIndex = index
        }
        return view
    }

    func updateUIView(_ uiView: LiquidGlassTabBarView, context: Context) {
        uiView.update(selectedIndex: selectedIndex, isDark: isDark, animated: true)
    }
}

final class LiquidGlassTabBarView: UIView {
    // MARK: - Constants (from Telegram's TabBarComponent & LiquidLensView)
    private enum Constants {
        static let innerInset: CGFloat = 4.0
        static let liftedInset: CGFloat = 4.0
        static let springDuration: TimeInterval = 0.4
        static let bounceAmplitude: CGFloat = 8.0  // How much it bounces
        static let bounceFrequency: CGFloat = 3.0  // Bounce speed
        static let bounceDamping: CGFloat = 0.15   // How fast bounce decays
    }

    // MARK: - Views
    private let glassView: LiquidGlassView
    private let selectionIndicator: UIView  // Simple selection indicator
    private let selectionBlur: UIVisualEffectView
    private var itemViews: [TabBarItemView] = []
    private var items: [TabBarItem]

    // MARK: - State
    var onSelect: ((Int) -> Void)?
    private var currentSelectedIndex: Int = 0
    private var previousSelectedIndex: Int = 0
    private var isLifted: Bool = false
    private var currentIsDark: Bool = false

    // Gesture state (like Telegram)
    private var selectionGestureState: (startX: CGFloat, currentX: CGFloat)?

    // Bounce animation state (like Telegram's liftedDisplayLink)
    private var displayLink: CADisplayLink?
    private var bounceStartTime: CFTimeInterval = 0
    private var bounceDirection: BounceDirection = .horizontal
    private var targetLensFrame: CGRect = .zero

    private enum BounceDirection {
        case horizontal  // Left-right movement
        case vertical    // Same position tap
    }

    // MARK: - Init
    init(items: [TabBarItem]) {
        self.items = items
        self.glassView = LiquidGlassView()
        self.selectionIndicator = UIView()
        self.selectionBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))

        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Setup
    private func setupUI() {
        // Glass background
        addSubview(glassView)

        // Selection indicator (simple approach - just a highlight)
        selectionIndicator.layer.cornerCurve = .continuous
        selectionIndicator.clipsToBounds = true
        addSubview(selectionIndicator)

        // Blur inside selection
        selectionBlur.alpha = 0.5
        selectionIndicator.addSubview(selectionBlur)

        // Tint overlay
        let tintView = UIView()
        tintView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        tintView.tag = 100
        selectionIndicator.addSubview(tintView)

        // Create item views (single set - color changes based on selection)
        for (index, item) in items.enumerated() {
            let itemView = TabBarItemView(item: item)
            itemView.tag = index
            itemView.isUserInteractionEnabled = false
            itemViews.append(itemView)
            addSubview(itemView)
        }

        // Tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)

        // Pan gesture for drag selection (like Telegram)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    // MARK: - Gestures
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        guard let index = itemIndex(at: location) else { return }
        guard index != currentSelectedIndex else { return }

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        // Lift animation then select
        performLiftedSelection(from: currentSelectedIndex, to: index)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)

        switch gesture.state {
        case .began:
            if let index = itemIndex(at: location) {
                let itemFrame = frameForItem(at: index)
                selectionGestureState = (itemFrame.minX - Constants.innerInset, itemFrame.minX - Constants.innerInset)
                updateLayout(animated: true, isLifted: true)
            }

        case .changed:
            if var state = selectionGestureState {
                state.currentX = state.startX + gesture.translation(in: self).x
                selectionGestureState = state
                updateLayout(animated: false, isLifted: true)
            }

        case .ended, .cancelled:
            selectionGestureState = nil
            if let index = itemIndex(at: location), index != currentSelectedIndex {
                performLiftedSelection(from: currentSelectedIndex, to: index)
            } else {
                updateLayout(animated: true, isLifted: false)
            }

        default:
            break
        }
    }

    private func performLiftedSelection(from fromIndex: Int, to toIndex: Int) {
        // Determine bounce direction based on movement
        let movingRight = toIndex > fromIndex
        let movingLeft = toIndex < fromIndex
        bounceDirection = (movingLeft || movingRight) ? .horizontal : .vertical

        previousSelectedIndex = fromIndex
        isLifted = true
        currentSelectedIndex = toIndex
        onSelect?(toIndex)

        // Calculate target lens frame
        let itemWidth = bounds.width / CGFloat(items.count)
        let selectedFrame = frameForItem(at: toIndex)
        let lensX = selectedFrame.minX - Constants.innerInset
        let lensWidth = itemWidth + Constants.innerInset * 2
        targetLensFrame = CGRect(
            x: lensX,
            y: 0,
            width: lensWidth,
            height: bounds.height
        )

        // Start bounce animation with DisplayLink (like Telegram)
        startBounceAnimation()

        // Animate items to new positions
        updateItemsLayout(animated: true, isLifted: true)

        // Animate lens with spring (the main movement)
        animateLensToTarget(lifted: true)

        // End lift after animation settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLifted = false
            self?.updateItemsLayout(animated: true, isLifted: false)
        }
    }

    // MARK: - Bounce Animation (like Telegram's liftedDisplayLink)

    private func startBounceAnimation() {
        displayLink?.invalidate()
        bounceStartTime = CACurrentMediaTime()

        displayLink = CADisplayLink(target: self, selector: #selector(updateBounceAnimation))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateBounceAnimation(_ link: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - bounceStartTime
        let t = CGFloat(elapsed)

        // Damped oscillation: A * e^(-damping*t) * sin(frequency*t)
        let decay = exp(-Constants.bounceDamping * t * 10)
        let oscillation = sin(t * Constants.bounceFrequency * .pi * 2)
        let bounce = Constants.bounceAmplitude * decay * oscillation

        // Stop when bounce is negligible
        if abs(bounce) < 0.1 && elapsed > 0.3 {
            displayLink?.invalidate()
            displayLink = nil

            // Ensure final position and reset transform
            selectionIndicator.transform = .identity
            selectionIndicator.frame = targetLensFrame
            selectionIndicator.layer.cornerRadius = targetLensFrame.height * 0.35
            layoutSelectionSubviews()
            return
        }

        // Squash and stretch like liquid water
        // When stretching in one direction, compress in the other (volume preservation)
        let stretchFactor = bounce / Constants.bounceAmplitude  // -1 to 1
        let stretchAmount: CGFloat = 0.08  // How much to stretch/squash

        var scaleX: CGFloat = 1.0
        var scaleY: CGFloat = 1.0
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        switch bounceDirection {
        case .horizontal:
            // Horizontal movement: stretch width, compress height
            let direction: CGFloat = previousSelectedIndex < currentSelectedIndex ? 1 : -1
            offsetX = bounce * direction

            // Stretch horizontally = compress vertically (like water)
            scaleX = 1.0 + stretchFactor * stretchAmount
            scaleY = 1.0 - stretchFactor * stretchAmount * 0.5  // Less compression to maintain volume

        case .vertical:
            // Vertical bounce: stretch height, compress width
            offsetY = bounce * 0.5

            // Stretch vertically = compress horizontally
            scaleY = 1.0 + stretchFactor * stretchAmount
            scaleX = 1.0 - stretchFactor * stretchAmount * 0.5
        }

        // Apply position offset
        var frame = targetLensFrame
        frame.origin.x += offsetX
        frame.origin.y += offsetY

        // Apply squash/stretch transform
        selectionIndicator.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        selectionIndicator.frame = frame
        selectionIndicator.layer.cornerRadius = frame.height * 0.35
        layoutSelectionSubviews()
    }

    private func layoutSelectionSubviews() {
        let bounds = selectionIndicator.bounds
        selectionBlur.frame = bounds
        if let tintView = selectionIndicator.viewWithTag(100) {
            tintView.frame = bounds
        }
    }

    private func animateLensToTarget(lifted: Bool) {
        let liftedInset = lifted ? -Constants.liftedInset : 0
        let frame = targetLensFrame.insetBy(dx: liftedInset, dy: liftedInset)

        // Use CASpringAnimation for more natural feel
        let positionAnimation = CASpringAnimation(keyPath: "position")
        positionAnimation.fromValue = NSValue(cgPoint: selectionIndicator.layer.position)
        positionAnimation.toValue = NSValue(cgPoint: CGPoint(x: frame.midX, y: frame.midY))
        positionAnimation.damping = 12
        positionAnimation.stiffness = 180
        positionAnimation.mass = 1.0
        positionAnimation.initialVelocity = 0
        positionAnimation.duration = positionAnimation.settlingDuration
        positionAnimation.fillMode = .forwards
        positionAnimation.isRemovedOnCompletion = false

        let boundsAnimation = CASpringAnimation(keyPath: "bounds.size")
        boundsAnimation.fromValue = NSValue(cgSize: selectionIndicator.bounds.size)
        boundsAnimation.toValue = NSValue(cgSize: frame.size)
        boundsAnimation.damping = 12
        boundsAnimation.stiffness = 180
        boundsAnimation.mass = 1.0
        boundsAnimation.duration = boundsAnimation.settlingDuration
        boundsAnimation.fillMode = .forwards
        boundsAnimation.isRemovedOnCompletion = false

        selectionIndicator.layer.add(positionAnimation, forKey: "position")
        selectionIndicator.layer.add(boundsAnimation, forKey: "bounds.size")

        // Update actual values
        selectionIndicator.layer.position = CGPoint(x: frame.midX, y: frame.midY)
        selectionIndicator.bounds.size = frame.size
        selectionIndicator.layer.cornerRadius = frame.height * 0.35
        layoutSelectionSubviews()
    }

    private func itemIndex(at point: CGPoint) -> Int? {
        let itemWidth = bounds.width / CGFloat(items.count)
        let index = Int(point.x / itemWidth)
        if index >= 0 && index < items.count {
            return index
        }
        return nil
    }

    private func frameForItem(at index: Int) -> CGRect {
        let itemWidth = bounds.width / CGFloat(items.count)
        let itemSize = CGSize(width: itemWidth, height: bounds.height - Constants.innerInset * 2)
        return CGRect(
            origin: CGPoint(x: Constants.innerInset + CGFloat(index) * itemWidth, y: Constants.innerInset),
            size: itemSize
        )
    }

    // MARK: - Update
    func update(selectedIndex: Int, isDark: Bool, animated: Bool) {
        let previousIndex = currentSelectedIndex
        let wasChanged = previousIndex != selectedIndex
        currentIsDark = isDark

        // Update glass background
        glassView.update(size: bounds.size, cornerRadius: bounds.height / 2, isDark: isDark, animated: animated)

        if wasChanged && animated {
            // Use the lifted selection for tab changes
            performLiftedSelection(from: previousIndex, to: selectedIndex)
        } else {
            currentSelectedIndex = selectedIndex
            updateLayout(animated: animated, isLifted: isLifted)
        }
    }

    private func updateItemsLayout(animated: Bool, isLifted: Bool) {
        let itemWidth = bounds.width / CGFloat(items.count)
        _ = CGSize(width: itemWidth, height: bounds.height - Constants.innerInset * 2)

        // Update item frames and colors
        for (index, itemView) in itemViews.enumerated() {
            let itemFrame = CGRect(
                origin: CGPoint(x: CGFloat(index) * itemWidth, y: 0),
                size: CGSize(width: itemWidth, height: bounds.height)
            )

            let isSelected = index == currentSelectedIndex

            if animated {
                // Scale animation for selected item
                if isSelected {
                    let scaleAnimation = CASpringAnimation(keyPath: "transform.scale")
                    scaleAnimation.fromValue = itemView.layer.presentation()?.value(forKeyPath: "transform.scale") ?? 1.0
                    scaleAnimation.toValue = isLifted ? 1.1 : 1.0
                    scaleAnimation.damping = 10
                    scaleAnimation.stiffness = 200
                    scaleAnimation.mass = 0.8
                    scaleAnimation.duration = scaleAnimation.settlingDuration
                    itemView.layer.add(scaleAnimation, forKey: "scale")
                    itemView.transform = isLifted ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
                } else {
                    itemView.transform = .identity
                }

                UIView.animate(withDuration: Constants.springDuration, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                    itemView.frame = itemFrame
                }
            } else {
                itemView.frame = itemFrame
                itemView.transform = (isSelected && isLifted) ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
            }

            // Update colors - selected item is blue, others are dimmed
            itemView.update(isSelected: isSelected, isDark: currentIsDark, animated: animated)
        }
    }

    private func updateLayout(animated: Bool, isLifted: Bool) {
        updateItemsLayout(animated: animated, isLifted: isLifted)

        let itemWidth = bounds.width / CGFloat(items.count)

        // Calculate selection indicator frame
        let indicatorX: CGFloat
        let indicatorWidth: CGFloat

        if let gestureState = selectionGestureState {
            // During drag
            indicatorX = gestureState.currentX
            indicatorWidth = itemWidth
        } else {
            // Normal selection
            indicatorX = CGFloat(currentSelectedIndex) * itemWidth
            indicatorWidth = itemWidth
        }

        // Indicator frame with lift expansion
        let padding: CGFloat = 4.0
        let liftedInset = isLifted ? -Constants.liftedInset : 0
        let indicatorFrame = CGRect(
            x: indicatorX + padding + liftedInset,
            y: padding + liftedInset,
            width: indicatorWidth - padding * 2 - liftedInset * 2,
            height: bounds.height - padding * 2 - liftedInset * 2
        )

        targetLensFrame = CGRect(
            x: indicatorX + padding,
            y: padding,
            width: indicatorWidth - padding * 2,
            height: bounds.height - padding * 2
        )

        // Animate selection indicator
        if animated {
            UIView.animate(
                withDuration: Constants.springDuration,
                delay: 0,
                usingSpringWithDamping: 0.65,  // More bouncy like Telegram
                initialSpringVelocity: 0.8,
                options: [.allowUserInteraction]
            ) {
                self.selectionIndicator.frame = indicatorFrame
                self.selectionIndicator.layer.cornerRadius = indicatorFrame.height * 0.35
                self.layoutSelectionSubviews()
            }
        } else {
            selectionIndicator.frame = indicatorFrame
            selectionIndicator.layer.cornerRadius = indicatorFrame.height * 0.35
            layoutSelectionSubviews()
        }

        // Update blur style based on dark mode
        selectionBlur.effect = UIBlurEffect(style: currentIsDark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()

        glassView.frame = bounds
        update(selectedIndex: currentSelectedIndex, isDark: currentIsDark, animated: false)
    }
}

// MARK: - Tab Bar Item View

private final class TabBarItemView: UIView {
    private let iconImageView: UIImageView
    private let titleLabel: UILabel
    private let badgeView: UIView
    private let badgeLabel: UILabel

    private let item: TabBarItem

    init(item: TabBarItem) {
        self.item = item
        self.iconImageView = UIImageView()
        self.titleLabel = UILabel()
        self.badgeView = UIView()
        self.badgeLabel = UILabel()

        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // Icon
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.image = UIImage(systemName: item.icon)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 22, weight: .medium))
        addSubview(iconImageView)

        // Title
        titleLabel.text = item.title
        titleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        titleLabel.textAlignment = .center
        addSubview(titleLabel)

        // Badge
        badgeView.backgroundColor = UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0) // Telegram red
        badgeView.layer.cornerRadius = 9
        badgeView.isHidden = item.badge == 0
        addSubview(badgeView)

        badgeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        badgeLabel.textColor = .white
        badgeLabel.textAlignment = .center
        badgeLabel.text = item.badge > 0 ? "\(item.badge)" : nil
        badgeView.addSubview(badgeLabel)
    }

    func update(isSelected: Bool, isDark: Bool, animated: Bool) {
        // Telegram blue for selected, dimmed white for unselected
        let selectedColor = UIColor(red: 0.35, green: 0.56, blue: 0.96, alpha: 1.0)
        let normalColor = UIColor.white.withAlphaComponent(isDark ? 0.5 : 0.6)
        let targetColor = isSelected ? selectedColor : normalColor

        let updateBlock = {
            self.iconImageView.tintColor = targetColor
            self.titleLabel.textColor = targetColor
        }

        if animated {
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [.allowUserInteraction],
                animations: updateBlock
            )
        } else {
            updateBlock()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let iconSize: CGFloat = 24
        let titleHeight: CGFloat = 12
        let spacing: CGFloat = 2
        let totalHeight = iconSize + spacing + titleHeight

        let iconY = (bounds.height - totalHeight) / 2
        iconImageView.frame = CGRect(
            x: (bounds.width - iconSize) / 2,
            y: iconY,
            width: iconSize,
            height: iconSize
        )

        titleLabel.frame = CGRect(
            x: 0,
            y: iconImageView.frame.maxY + spacing,
            width: bounds.width,
            height: titleHeight
        )

        // Badge positioned at top-right of icon
        let badgeWidth: CGFloat = max(18, badgeLabel.intrinsicContentSize.width + 8)
        badgeView.frame = CGRect(
            x: iconImageView.frame.maxX - 4,
            y: iconImageView.frame.minY - 4,
            width: badgeWidth,
            height: 18
        )
        badgeLabel.frame = badgeView.bounds
    }
}

// MARK: - Test View

struct LiquidGlassTestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isDarkMode = true  // Start in dark mode like Telegram
    @State private var selectedTabIndex = 3

    // Telegram-style tab items
    private let tabItems: [TabBarItem] = [
        TabBarItem(icon: "person.2.fill", title: "Contacts", badge: 1),
        TabBarItem(icon: "phone.fill", title: "Calls"),
        TabBarItem(icon: "bubble.left.and.bubble.right.fill", title: "Chats", badge: 12),
        TabBarItem(icon: "gearshape.fill", title: "Settings")
    ]

    var body: some View {
        ZStack {
            backgroundContent

            ScrollView {
                VStack(spacing: 24) {
                    Color.clear.frame(height: 100)

                    Toggle("Dark Mode", isOn: $isDarkMode)
                        .padding(16)
                        .foregroundColor(.white)
                        .liquidGlass(cornerRadius: 16)

                    sectionHeader("Telegram-Style Tab Bar")
                    LiquidGlassTabBar(items: tabItems, selectedIndex: $selectedTabIndex, isDark: isDarkMode)
                        .frame(height: 70)  // Taller like Telegram
                        .padding(.horizontal, 8)

                    sectionHeader("Glass Cards")
                    glassCardsSection

                    sectionHeader("Glass Buttons")
                    glassButtonsSection

                    sectionHeader("Improvements Made")
                    improvementsCard

                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 16)
            }

            VStack {
                glassHeader
                Spacer()
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, isDarkMode ? .dark : .light)
    }

    private var backgroundContent: some View {
        ZStack {
            LinearGradient(
                colors: isDarkMode ? [
                    Color(hex: "1a1a2e"),
                    Color(hex: "16213e"),
                    Color(hex: "0f3460")
                ] : [
                    Color(hex: "667EEA"),
                    Color(hex: "764BA2"),
                    Color(hex: "F093FB"),
                    Color(hex: "F5576C")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 200, height: 200)
                    .offset(x: geo.size.width * 0.6, y: geo.size.height * 0.1)

                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 150, height: 150)
                    .offset(x: geo.size.width * 0.1, y: geo.size.height * 0.3)

                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.55)
            }
        }
    }

    private var glassHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .liquidGlass(cornerRadius: 16)
            }

            Spacer()

            Text("Liquid Glass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
        .padding(.bottom, 16)
        .background(
            LiquidGlassBackgroundView(
                size: CGSize(width: UIScreen.main.bounds.width, height: 120),
                cornerRadius: 0,
                isDark: isDarkMode,
                tintColor: .white.opacity(0.6)
            )
            .ignoresSafeArea()
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white.opacity(0.8))
            .textCase(.uppercase)
            .tracking(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var glassCardsSection: some View {
        VStack(spacing: 12) {
            ForEach(0..<3) { index in
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: ["message.fill", "bell.fill", "gear"][index])
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(["Messages", "Notifications", "Settings"][index])
                            .font(.system(size: 15, weight: .medium))
                        Text(["12 unread", "3 new", "Account"][index])
                            .font(.system(size: 12))
                            .opacity(0.6)
                    }
                    .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(16)
                .liquidGlass(cornerRadius: 16)
            }
        }
    }

    private var glassButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {}) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Send Message")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .liquidGlass(cornerRadius: 16)
            }

            HStack(spacing: 12) {
                ForEach(["heart.fill", "star.fill", "bell.fill", "bookmark.fill"], id: \.self) { icon in
                    Button(action: {}) {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .liquidGlass(cornerRadius: 25)
                    }
                }
            }
        }
    }

    private var improvementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Telegram-Style Features")
                    .font(.system(size: 16, weight: .semibold))
            }

            Divider().background(Color.white.opacity(0.2))

            VStack(alignment: .leading, spacing: 8) {
                featureItem("Color matrix filter (light/dark)", done: true)
                featureItem("Custom blur radius (8.0)", done: true)
                featureItem("Hidden VisualEffectSubview", done: true)
                featureItem("Spring animations", done: true)
                featureItem("Selection indicator with animation", done: true)
                featureItem("Multiple shadow layers", done: true)
                featureItem("Edge gradient highlights", done: true)
            }
            .font(.system(size: 13))
        }
        .foregroundColor(.white)
        .padding(20)
        .liquidGlass(cornerRadius: 20)
    }

    private func featureItem(_ text: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(done ? .green : .white.opacity(0.3))
                .font(.system(size: 14))
            Text(text)
                .opacity(0.85)
        }
    }
}

#Preview {
    LiquidGlassTestView()
}
