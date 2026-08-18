import QuartzCore
import UIKit

@MainActor
final class ShimmerEngine {
  private static let slideAnimationKey = "com.sunset.shimmer.slide"
  private static let fadeAnimationKey = "com.sunset.shimmer.fade"

  let contentLayer: CALayer

  private(set) var isShimmering = false
  private var activeConfiguration: ShimmerConfiguration
  private var animationDuration: CFTimeInterval?
  private var animationStartTime: CFTimeInterval?
  private var fadeLayer: CALayer?
  private var maskLayer: CAGradientLayer?
  private var requestedConfiguration: ShimmerConfiguration
  private var transitionDelegate: ShimmerAnimationDelegate?
  private var transitionGeneration = 0
  private var travelDistance: CGFloat?

  var configuration: ShimmerConfiguration {
    get { requestedConfiguration }
    set {
      guard newValue != requestedConfiguration else { return }
      requestedConfiguration = newValue
      if isShimmering {
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
    isShimmering = true
    activeConfiguration = requestedConfiguration
    installMaskAndAnimationIfPossible(startTime: startTime, includeBeginFade: true)
  }

  func stop(_ mode: ShimmerStopMode) {
    switch mode {
    case .smooth:
      guard isShimmering else { return }
      isShimmering = false
      cancelPendingTransition()
      scheduleSmoothStopIfPossible()

    case .immediate:
      guard isShimmering || maskLayer != nil else { return }
      isShimmering = false
      cancelPendingTransition()
      activeConfiguration = requestedConfiguration
      removeMaskImmediately()
    }
  }

  func layoutDidChange() {
    guard isShimmering, let animationStartTime else { return }
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
    let bounds = contentLayer.bounds
    guard bounds.width > 0, bounds.height > 0 else { return }

    removeMaskImmediately()

    let configuration = activeConfiguration
    let length = bounds.width
    let extraDistance = length + configuration.speed * configuration.pauseDuration
    let fullMaskLength = length * 3 + extraDistance
    let travelDistance = length * 2 + extraDistance
    let highlightOutsideLength = (1 - configuration.highlightLength) / 2

    let maskLayer = CAGradientLayer()
    maskLayer.anchorPoint = .zero
    maskLayer.bounds = CGRect(
      x: 0,
      y: 0,
      width: fullMaskLength,
      height: bounds.height
    )
    maskLayer.position = CGPoint(x: -travelDistance, y: 0)
    maskLayer.startPoint = CGPoint(
      x: (length + extraDistance) / fullMaskLength,
      y: 0.5
    )
    maskLayer.endPoint = CGPoint(
      x: travelDistance / fullMaskLength,
      y: 0.5
    )
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

    let animationDuration = (length / configuration.speed) + configuration.pauseDuration
    let slide = makeSlideAnimation(
      travelDistance: travelDistance,
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

    self.animationDuration = animationDuration
    animationStartTime = startTime.mediaTime
    self.fadeLayer = fadeLayer
    self.maskLayer = maskLayer
    self.travelDistance = travelDistance
  }

  private func scheduleConfigurationTransitionIfNeeded() {
    guard transitionDelegate == nil,
      let maskLayer,
      let animationDuration,
      let animationStartTime,
      let travelDistance
    else { return }

    let boundary = nextSweepBoundary(
      after: CACurrentMediaTime(),
      startTime: animationStartTime,
      duration: animationDuration
    )
    let finishSlide = makeSlideAnimation(
      travelDistance: travelDistance,
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
      let travelDistance
    else {
      activeConfiguration = requestedConfiguration
      removeMaskImmediately()
      return
    }

    let boundary = nextSweepBoundary(
      after: CACurrentMediaTime(),
      startTime: animationStartTime,
      duration: animationDuration
    )
    let finishSlide = makeSlideAnimation(
      travelDistance: travelDistance,
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
    travelDistance: CGFloat,
    duration: CFTimeInterval,
    beginTime: CFTimeInterval,
    repeats: Bool
  ) -> CABasicAnimation {
    let slide = CABasicAnimation(keyPath: "position.x")
    slide.fromValue = -travelDistance
    slide.toValue = 0
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
    animationDuration = nil
    animationStartTime = nil
    fadeLayer = nil
    maskLayer = nil
    travelDistance = nil
  }
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
