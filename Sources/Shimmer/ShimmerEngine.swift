import QuartzCore
import UIKit

@MainActor
final class ShimmerEngine {
  private static let fadeAnimationKey = "com.sunset.shimmer.fade"
  private static let slideAnimationKey = "com.sunset.shimmer.slide"

  let contentLayer: CALayer

  private(set) var isShimmering = false
  private var activeConfiguration: ShimmerConfiguration
  private var activeGeometry: ShimmerGeometry?
  private var animationDuration: CFTimeInterval?
  private var animationStartTime: CFTimeInterval?
  private var fadeLayer: CALayer?
  private var installedBounds: CGRect?
  private var isPaused = false
  private var maskLayer: CAGradientLayer?
  private var requestedConfiguration: ShimmerConfiguration
  private var transitionDelegate: ShimmerAnimationDelegate?
  private var transitionGeneration = 0

  var configuration: ShimmerConfiguration {
    get { requestedConfiguration }
    set {
      guard newValue != requestedConfiguration else { return }
      requestedConfiguration = newValue
      if isShimmering, maskLayer != nil {
        scheduleConfigurationTransitionIfNeeded()
      } else {
        activeConfiguration = newValue
      }
    }
  }

  init(
    contentLayer: CALayer,
    configuration: ShimmerConfiguration = .default
  ) {
    self.contentLayer = contentLayer
    activeConfiguration = configuration
    requestedConfiguration = configuration
  }

  func start(at startTime: ShimmerStartTime) {
    guard !isShimmering else { return }
    cancelPendingTransition()
    removeMaskImmediately()
    isPaused = false
    isShimmering = true
    activeConfiguration = requestedConfiguration
    animationStartTime = startTime.mediaTime
    installMaskAndAnimationIfPossible(startTime: startTime, includeBeginFade: true)
  }

  func stop(_ mode: ShimmerStopMode) {
    switch mode {
    case .smooth:
      guard isShimmering else { return }
      isShimmering = false
      if isPaused {
        resumeMaskTimeline()
        isPaused = false
      }
      cancelPendingTransition()
      scheduleSmoothStopIfPossible()

    case .immediate:
      guard isShimmering || maskLayer != nil else { return }
      isShimmering = false
      isPaused = false
      cancelPendingTransition()
      activeConfiguration = requestedConfiguration
      removeMaskImmediately()
      animationStartTime = nil
    }
  }

  func pause() {
    guard isShimmering, !isPaused else { return }
    isPaused = true
    pauseMaskTimeline()
  }

  func resume() {
    guard isShimmering, isPaused else { return }
    isPaused = false
    resumeMaskTimeline()
    layoutDidChange()
  }

  func layoutDidChange() {
    guard isShimmering, let animationStartTime else { return }
    let bounds = contentLayer.bounds

    guard bounds.width > 0, bounds.height > 0 else {
      if maskLayer != nil {
        cancelPendingTransition()
        removeMaskImmediately()
      }
      return
    }

    guard maskLayer == nil || installedBounds != bounds else { return }
    cancelPendingTransition()
    installMaskAndAnimationIfPossible(
      startTime: ShimmerStartTime(mediaTime: animationStartTime),
      includeBeginFade: false
    )
    if requestedConfiguration != activeConfiguration {
      scheduleConfigurationTransitionIfNeeded()
    }
  }

  private func installMaskAndAnimationIfPossible(
    startTime: ShimmerStartTime,
    includeBeginFade: Bool
  ) {
    animationStartTime = startTime.mediaTime
    let bounds = contentLayer.bounds
    guard bounds.width > 0, bounds.height > 0 else { return }

    removeMaskImmediately()

    let configuration = activeConfiguration
    let geometry = makeGeometry(bounds: bounds, configuration: configuration)
    let highlightOutsideLength = (1 - configuration.highlightLength) / 2

    let maskLayer = CAGradientLayer()
    maskLayer.anchorPoint = .zero
    maskLayer.bounds = geometry.maskBounds
    maskLayer.position = geometry.initialPosition
    maskLayer.startPoint = geometry.gradientStartPoint
    maskLayer.endPoint = geometry.gradientEndPoint
    maskLayer.locations = [
      NSNumber(value: highlightOutsideLength),
      0.5,
      NSNumber(value: 1 - highlightOutsideLength),
    ]
    maskLayer.colors = [
      UIColor(white: 1, alpha: CGFloat(configuration.baseOpacity)).cgColor,
      UIColor(white: 1, alpha: CGFloat(configuration.animationOpacity)).cgColor,
      UIColor(white: 1, alpha: CGFloat(configuration.baseOpacity)).cgColor,
    ]

    let fadeLayer = CALayer()
    fadeLayer.backgroundColor = UIColor.white.cgColor
    fadeLayer.frame = maskLayer.bounds
    fadeLayer.opacity = 0
    maskLayer.addSublayer(fadeLayer)

    let animationDuration =
      (geometry.contentLength / configuration.speed) + configuration.pauseDuration
    let slide = makeSlideAnimation(
      geometry: geometry,
      duration: animationDuration,
      beginTime: startTime.mediaTime,
      repeats: true
    )

    if includeBeginFade, configuration.beginFadeDuration > 0 {
      let beginFade = CABasicAnimation(keyPath: "opacity")
      beginFade.fromValue = 1
      beginFade.toValue = 0
      beginFade.beginTime = startTime.mediaTime
      beginFade.duration = configuration.beginFadeDuration
      beginFade.fillMode = .both
      beginFade.isRemovedOnCompletion = false
      fadeLayer.add(beginFade, forKey: Self.fadeAnimationKey)
    }

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    contentLayer.mask = maskLayer
    CATransaction.commit()
    maskLayer.add(slide, forKey: Self.slideAnimationKey)

    activeGeometry = geometry
    self.animationDuration = animationDuration
    self.fadeLayer = fadeLayer
    installedBounds = bounds
    self.maskLayer = maskLayer

    if isPaused {
      pauseMaskTimeline()
    }
  }

  private func makeGeometry(
    bounds: CGRect,
    configuration: ShimmerConfiguration
  ) -> ShimmerGeometry {
    let isHorizontal: Bool
    switch configuration.direction {
    case .leftToRight, .rightToLeft:
      isHorizontal = true
    case .topToBottom, .bottomToTop:
      isHorizontal = false
    }

    let contentLength = isHorizontal ? bounds.width : bounds.height
    let extraDistance = contentLength + configuration.speed * configuration.pauseDuration
    let fullMaskLength = contentLength * 3 + extraDistance
    let travelDistance = contentLength * 2 + extraDistance
    let gradientStart = (contentLength + extraDistance) / fullMaskLength
    let gradientEnd = travelDistance / fullMaskLength

    let axisKeyPath: String
    let fromValue: CGFloat
    let toValue: CGFloat
    let initialPosition: CGPoint
    let maskBounds: CGRect
    let gradientStartPoint: CGPoint
    let gradientEndPoint: CGPoint

    switch configuration.direction {
    case .leftToRight:
      axisKeyPath = "position.x"
      fromValue = -travelDistance
      toValue = 0
      initialPosition = CGPoint(x: fromValue, y: 0)
      maskBounds = CGRect(x: 0, y: 0, width: fullMaskLength, height: bounds.height)
      gradientStartPoint = CGPoint(x: gradientStart, y: 0.5)
      gradientEndPoint = CGPoint(x: gradientEnd, y: 0.5)

    case .rightToLeft:
      axisKeyPath = "position.x"
      fromValue = 0
      toValue = -travelDistance
      initialPosition = CGPoint(x: fromValue, y: 0)
      maskBounds = CGRect(x: 0, y: 0, width: fullMaskLength, height: bounds.height)
      gradientStartPoint = CGPoint(x: gradientStart, y: 0.5)
      gradientEndPoint = CGPoint(x: gradientEnd, y: 0.5)

    case .topToBottom:
      axisKeyPath = "position.y"
      fromValue = -travelDistance
      toValue = 0
      initialPosition = CGPoint(x: 0, y: fromValue)
      maskBounds = CGRect(x: 0, y: 0, width: bounds.width, height: fullMaskLength)
      gradientStartPoint = CGPoint(x: 0.5, y: gradientStart)
      gradientEndPoint = CGPoint(x: 0.5, y: gradientEnd)

    case .bottomToTop:
      axisKeyPath = "position.y"
      fromValue = 0
      toValue = -travelDistance
      initialPosition = CGPoint(x: 0, y: fromValue)
      maskBounds = CGRect(x: 0, y: 0, width: bounds.width, height: fullMaskLength)
      gradientStartPoint = CGPoint(x: 0.5, y: gradientStart)
      gradientEndPoint = CGPoint(x: 0.5, y: gradientEnd)
    }

    return ShimmerGeometry(
      axisKeyPath: axisKeyPath,
      contentLength: contentLength,
      fromValue: fromValue,
      gradientEndPoint: gradientEndPoint,
      gradientStartPoint: gradientStartPoint,
      initialPosition: initialPosition,
      maskBounds: maskBounds,
      toValue: toValue
    )
  }

  private func scheduleConfigurationTransitionIfNeeded() {
    guard transitionDelegate == nil,
      let maskLayer,
      let animationDuration,
      let animationStartTime,
      let activeGeometry
    else { return }

    let boundary = nextSweepBoundary(
      after: CACurrentMediaTime(),
      startTime: animationStartTime,
      duration: animationDuration
    )
    let finishSlide = makeSlideAnimation(
      geometry: activeGeometry,
      duration: animationDuration,
      beginTime: boundary - animationDuration,
      repeats: false
    )
    let generation = transitionGeneration
    let transitionDelegate = ShimmerAnimationDelegate { [weak self] finished in
      guard let self,
        finished,
        generation == self.transitionGeneration,
        self.isShimmering
      else { return }

      self.transitionDelegate = nil
      self.activeConfiguration = self.requestedConfiguration
      self.installMaskAndAnimationIfPossible(
        startTime: ShimmerStartTime(mediaTime: boundary),
        includeBeginFade: false
      )
    }
    self.transitionDelegate = transitionDelegate
    finishSlide.delegate = transitionDelegate
    maskLayer.add(finishSlide, forKey: Self.slideAnimationKey)
  }

  private func scheduleSmoothStopIfPossible() {
    guard let maskLayer,
      let fadeLayer,
      let animationDuration,
      let animationStartTime,
      let activeGeometry
    else {
      activeConfiguration = requestedConfiguration
      removeMaskImmediately()
      self.animationStartTime = nil
      return
    }

    let boundary = nextSweepBoundary(
      after: CACurrentMediaTime(),
      startTime: animationStartTime,
      duration: animationDuration
    )
    let finishSlide = makeSlideAnimation(
      geometry: activeGeometry,
      duration: animationDuration,
      beginTime: boundary - animationDuration,
      repeats: false
    )
    maskLayer.add(finishSlide, forKey: Self.slideAnimationKey)

    let endFade = CABasicAnimation(keyPath: "opacity")
    endFade.fromValue = fadeLayer.presentation()?.opacity ?? fadeLayer.opacity
    endFade.toValue = 1
    endFade.beginTime = boundary
    endFade.duration = activeConfiguration.endFadeDuration
    endFade.fillMode = .both
    endFade.isRemovedOnCompletion = false

    let generation = transitionGeneration
    let transitionDelegate = ShimmerAnimationDelegate { [weak self] finished in
      guard let self,
        finished,
        generation == self.transitionGeneration,
        !self.isShimmering
      else { return }

      self.transitionDelegate = nil
      self.activeConfiguration = self.requestedConfiguration
      self.removeMaskImmediately()
      self.animationStartTime = nil
    }
    self.transitionDelegate = transitionDelegate
    endFade.delegate = transitionDelegate

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    fadeLayer.opacity = 1
    CATransaction.commit()
    fadeLayer.add(endFade, forKey: Self.fadeAnimationKey)
  }

  private func makeSlideAnimation(
    geometry: ShimmerGeometry,
    duration: CFTimeInterval,
    beginTime: CFTimeInterval,
    repeats: Bool
  ) -> CABasicAnimation {
    let slide = CABasicAnimation(keyPath: geometry.axisKeyPath)
    slide.fromValue = geometry.fromValue
    slide.toValue = geometry.toValue
    slide.duration = duration
    slide.beginTime = beginTime
    slide.repeatCount = repeats ? .infinity : 0
    slide.fillMode = .forwards
    slide.isRemovedOnCompletion = false
    return slide
  }

  private func nextSweepBoundary(
    after time: CFTimeInterval,
    startTime: CFTimeInterval,
    duration: CFTimeInterval
  ) -> CFTimeInterval {
    guard time >= startTime else { return startTime + duration }
    let elapsed = time - startTime
    let completedSweeps = floor(elapsed / duration)
    return startTime + (completedSweeps + 1) * duration
  }

  private func pauseMaskTimeline() {
    guard let maskLayer, maskLayer.speed != 0 else { return }
    let pauseTime = maskLayer.convertTime(CACurrentMediaTime(), from: nil)
    maskLayer.speed = 0
    maskLayer.timeOffset = pauseTime
  }

  private func resumeMaskTimeline() {
    guard let maskLayer, maskLayer.speed == 0 else { return }
    maskLayer.speed = 1
    maskLayer.timeOffset = 0
    maskLayer.beginTime = 0
  }

  private func cancelPendingTransition() {
    transitionGeneration += 1
    transitionDelegate = nil
  }

  private func removeMaskImmediately() {
    maskLayer?.removeAllAnimations()
    fadeLayer?.removeAllAnimations()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    if contentLayer.mask === maskLayer {
      contentLayer.mask = nil
    }
    CATransaction.commit()
    activeGeometry = nil
    animationDuration = nil
    fadeLayer = nil
    installedBounds = nil
    maskLayer = nil
  }
}

private struct ShimmerGeometry {
  let axisKeyPath: String
  let contentLength: CGFloat
  let fromValue: CGFloat
  let gradientEndPoint: CGPoint
  let gradientStartPoint: CGPoint
  let initialPosition: CGPoint
  let maskBounds: CGRect
  let toValue: CGFloat
}

private final class ShimmerAnimationDelegate: NSObject, CAAnimationDelegate {
  private let completion: @MainActor @Sendable (Bool) -> Void

  init(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
    self.completion = completion
  }

  nonisolated func animationDidStop(_: CAAnimation, finished flag: Bool) {
    Task { @MainActor [completion] in
      completion(flag)
    }
  }
}
