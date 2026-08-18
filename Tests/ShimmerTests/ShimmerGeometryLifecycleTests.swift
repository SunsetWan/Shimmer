import Foundation
import QuartzCore
import UIKit
import XCTest

@testable import Shimmer

@MainActor
final class ShimmerGeometryLifecycleTests: XCTestCase {
  func testFourPhysicalDirectionsEnterAndExitOnTheExpectedAxis() throws {
    let expectations: [(ShimmerDirection, String, Bool)] = [
      (.leftToRight, "position.x", true),
      (.rightToLeft, "position.x", false),
      (.topToBottom, "position.y", true),
      (.bottomToTop, "position.y", false),
    ]

    for (direction, axisKeyPath, increasesAlongAxis) in expectations {
      let layer = makeLayer()
      layer.configuration = try makeConfiguration(direction: direction)

      layer.start()

      let mask = try XCTUnwrap(layer.contentLayer.mask as? CAGradientLayer)
      let slide = try observableAnimation(keyPath: axisKeyPath, in: mask)
      let fromValue = try XCTUnwrap(slide.fromValue as? CGFloat)
      let toValue = try XCTUnwrap(slide.toValue as? CGFloat)

      if increasesAlongAxis {
        XCTAssertLessThan(fromValue, toValue, "\(direction)")
      } else {
        XCTAssertGreaterThan(fromValue, toValue, "\(direction)")
      }

      switch direction {
      case .leftToRight, .rightToLeft:
        XCTAssertEqual(mask.position.x, fromValue, accuracy: 0.000_1)
        XCTAssertGreaterThan(mask.bounds.width, layer.contentLayer.bounds.width)
        XCTAssertEqual(mask.bounds.height, layer.contentLayer.bounds.height)

      case .topToBottom, .bottomToTop:
        XCTAssertEqual(mask.position.y, fromValue, accuracy: 0.000_1)
        XCTAssertGreaterThan(mask.bounds.height, layer.contentLayer.bounds.height)
        XCTAssertEqual(mask.bounds.width, layer.contentLayer.bounds.width)
      }

      layer.stop(.immediate)
    }
  }

  func testZeroBoundsStartDefersGeometryAndUsesOriginalStartTime() throws {
    let layer = ShimmeringLayer()
    layer.bounds = .zero
    let startTime = ShimmerStartTime.now

    layer.start(at: startTime)

    XCTAssertTrue(layer.isShimmering)
    XCTAssertNil(layer.contentLayer.mask)

    layer.bounds = CGRect(x: 0, y: 0, width: 160, height: 44)
    layer.setNeedsLayout()
    layer.layoutIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

    let slide = try observableAnimation(keyPath: "position.x", in: layer.contentLayer)
    XCTAssertEqual(slide.beginTime, startTime.mediaTime)
    XCTAssertNotNil(layer.contentLayer.mask)
    XCTAssertTrue(layer.isShimmering)
  }

  func testBoundsChangeRebuildsGeometryWithoutResettingTimeline() throws {
    let layer = makeLayer()
    let startTime = ShimmerStartTime.now
    layer.start(at: startTime)
    let originalMask = layer.contentLayer.mask
    let originalSlide = try observableAnimation(keyPath: "position.x", in: layer.contentLayer)

    layer.bounds = CGRect(x: 0, y: 0, width: 200, height: 80)
    layer.setNeedsLayout()
    layer.layoutIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

    let updatedMask = try XCTUnwrap(layer.contentLayer.mask as? CAGradientLayer)
    let updatedSlide = try observableAnimation(keyPath: "position.x", in: updatedMask)
    XCTAssertFalse(updatedMask === originalMask)
    XCTAssertEqual(layer.contentLayer.frame, layer.bounds)
    XCTAssertEqual(updatedSlide.beginTime, originalSlide.beginTime)
    XCTAssertGreaterThan(updatedSlide.duration, originalSlide.duration)
    XCTAssertTrue(layer.isShimmering)
  }

  func testViewPausesOffWindowAndResumesFromOriginalTimeline() throws {
    let (window, view) = makeVisibleView()
    let startTime = ShimmerStartTime.now
    view.start(at: startTime)
    let initialSlide = try observableAnimation(keyPath: "position.x", in: view.contentView.layer)
    let mask = try XCTUnwrap(view.contentView.layer.mask)

    view.removeFromSuperview()

    XCTAssertTrue(view.isShimmering)
    XCTAssertEqual(mask.speed, 0)
    XCTAssertGreaterThan(mask.timeOffset, 0)

    window.addSubview(view)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

    let resumedSlide = try observableAnimation(keyPath: "position.x", in: view.contentView.layer)
    XCTAssertTrue(view.isShimmering)
    XCTAssertEqual(mask.speed, 1)
    XCTAssertEqual(mask.timeOffset, 0)
    XCTAssertEqual(resumedSlide.beginTime, initialSlide.beginTime)
    window.isHidden = true
  }

  func testImmediateStopWhileDetachedPreventsRemountRecovery() {
    let (window, view) = makeVisibleView()
    view.start()
    view.removeFromSuperview()

    view.stop(.immediate)
    window.addSubview(view)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

    XCTAssertFalse(view.isShimmering)
    XCTAssertNil(view.contentView.layer.mask)
    window.isHidden = true
  }

  func testStandaloneLayerVisibilityRemainsCallerManaged() throws {
    let hostView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
    let layer = makeLayer()
    hostView.layer.addSublayer(layer)
    layer.start()
    let mask = try XCTUnwrap(layer.contentLayer.mask)

    layer.removeFromSuperlayer()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

    XCTAssertTrue(layer.isShimmering)
    XCTAssertEqual(mask.speed, 1)
    XCTAssertEqual(mask.timeOffset, 0)
    layer.stop(.immediate)
  }

  private func makeLayer() -> ShimmeringLayer {
    let layer = ShimmeringLayer()
    layer.bounds = CGRect(x: 0, y: 0, width: 100, height: 40)
    return layer
  }

  private func makeVisibleView() -> (UIWindow, ShimmeringView) {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
    let view = ShimmeringView(frame: window.bounds)
    window.addSubview(view)
    window.isHidden = false
    view.layoutIfNeeded()
    return (window, view)
  }

  private func makeConfiguration(
    direction: ShimmerDirection
  ) throws -> ShimmerConfiguration {
    try ShimmerConfiguration(
      speed: 230,
      pauseDuration: 0.4,
      highlightLength: 1,
      baseOpacity: 1,
      animationOpacity: 0.5,
      beginFadeDuration: 0.1,
      endFadeDuration: 0.3,
      direction: direction
    )
  }

  private func observableAnimation(
    keyPath: String,
    in rootLayer: CALayer
  ) throws -> CABasicAnimation {
    let animation = animations(in: rootLayer)
      .compactMap { $0 as? CABasicAnimation }
      .first { $0.keyPath == keyPath }
    return try XCTUnwrap(animation)
  }

  private func animations(in layer: CALayer) -> [CAAnimation] {
    let ownAnimations = layer.animationKeys()?.compactMap { layer.animation(forKey: $0) } ?? []
    let mask = layer.mask.map { [$0] } ?? []
    let childLayers = mask + (layer.sublayers ?? [])
    return ownAnimations + childLayers.flatMap(animations(in:))
  }
}
