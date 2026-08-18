import QuartzCore
import UIKit

@MainActor
final class ShimmerEngine {
  private static let slideAnimationKey = "com.sunset.shimmer.slide"

  let contentLayer: CALayer

  private(set) var isShimmering = false
  private var maskLayer: CAGradientLayer?
  private var startTime: ShimmerStartTime?
  private var storedConfiguration: ShimmerConfiguration

  var configuration: ShimmerConfiguration {
    get { storedConfiguration }
    set {
      guard newValue != storedConfiguration else { return }
      storedConfiguration = newValue
      if isShimmering {
        installMaskAndAnimationIfPossible()
      }
    }
  }

  init(
    contentLayer: CALayer,
    configuration: ShimmerConfiguration = .default
  ) {
    self.contentLayer = contentLayer
    storedConfiguration = configuration
  }

  func start(at startTime: ShimmerStartTime) {
    guard !isShimmering else { return }
    isShimmering = true
    self.startTime = startTime
    installMaskAndAnimationIfPossible()
  }

  func stop(_ mode: ShimmerStopMode) {
    guard isShimmering || maskLayer != nil else { return }
    isShimmering = false
    startTime = nil

    // Smooth completion is added by the timeline ticket. The minimal API keeps
    // both public cases available while guaranteeing immediate cleanup now.
    switch mode {
    case .smooth, .immediate:
      removeMaskImmediately()
    }
  }

  func layoutDidChange() {
    guard isShimmering else { return }
    installMaskAndAnimationIfPossible()
  }

  private func installMaskAndAnimationIfPossible() {
    let bounds = contentLayer.bounds
    guard bounds.width > 0, bounds.height > 0, let startTime else { return }

    removeMaskImmediately()

    let configuration = storedConfiguration
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

    let slide = CABasicAnimation(keyPath: "position.x")
    slide.fromValue = -travelDistance
    slide.toValue = 0
    slide.duration = (length / configuration.speed) + configuration.pauseDuration
    slide.beginTime = startTime.mediaTime
    slide.repeatCount = .infinity
    slide.fillMode = .forwards
    slide.isRemovedOnCompletion = false
    maskLayer.add(slide, forKey: Self.slideAnimationKey)

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    contentLayer.mask = maskLayer
    CATransaction.commit()
    self.maskLayer = maskLayer
  }

  private func removeMaskImmediately() {
    maskLayer?.removeAllAnimations()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    if contentLayer.mask === maskLayer {
      contentLayer.mask = nil
    }
    CATransaction.commit()
    maskLayer = nil
  }
}
