import Foundation
import QuartzCore
import UIKit
import XCTest

@testable import Shimmer

@MainActor
final class ShimmerTimelineTests: XCTestCase {
  func testSharedStartTimeProducesSharedPhaseWhileDifferentTimesRemainIndependent() throws {
    let first = makeLayer()
    let second = makeLayer()
    let sharedStartTime = ShimmerStartTime.now

    first.start(at: sharedStartTime)
    second.start(at: sharedStartTime)

    let firstSlide = try observableAnimation(keyPath: "position.x", in: first.contentLayer)
    let secondSlide = try observableAnimation(keyPath: "position.x", in: second.contentLayer)
    XCTAssertEqual(firstSlide.beginTime, secondSlide.beginTime)
    XCTAssertEqual(firstSlide.duration, secondSlide.duration)

    first.stop(.immediate)
    second.stop(.immediate)

    let independentStartTime = ShimmerStartTime(mediaTime: sharedStartTime.mediaTime + 0.25)
    first.start(at: sharedStartTime)
    second.start(at: independentStartTime)

    let restartedFirstSlide = try observableAnimation(keyPath: "position.x", in: first.contentLayer)
    let independentSecondSlide = try observableAnimation(
      keyPath: "position.x",
      in: second.contentLayer
    )
    XCTAssertNotEqual(restartedFirstSlide.beginTime, independentSecondSlide.beginTime)
  }

  func testPauseAndBeginFadeArePartOfTheObservableTimeline() throws {
    let layer = makeLayer()
    layer.configuration = try makeConfiguration(
      speed: 200,
      pauseDuration: 0.4,
      beginFadeDuration: 0.2
    )
    let startTime = ShimmerStartTime.now

    layer.start(at: startTime)

    let slide = try observableAnimation(keyPath: "position.x", in: layer.contentLayer)
    let beginFade = try observableAnimation(keyPath: "opacity", in: layer.contentLayer)
    XCTAssertEqual(slide.duration, 0.9, accuracy: 0.000_1)
    XCTAssertEqual(slide.beginTime, startTime.mediaTime)
    XCTAssertEqual(beginFade.duration, 0.2, accuracy: 0.000_1)
    XCTAssertEqual(beginFade.beginTime, startTime.mediaTime)
  }

  func testSmoothStopFinishesCurrentSweepAndEndFadeBeforeRemovingMask() throws {
    let (window, view) = makeVisibleView()
    view.configuration = try makeConfiguration(
      speed: 20_000,
      pauseDuration: 0,
      beginFadeDuration: 0,
      endFadeDuration: 0.01
    )
    view.start()

    view.stop(.smooth)
    let maskDuringStop = view.contentView.layer.mask
    view.stop(.smooth)

    XCTAssertFalse(view.isShimmering)
    XCTAssertNotNil(maskDuringStop)
    XCTAssertTrue(view.contentView.layer.mask === maskDuringStop)
    let finishSlide = try observableAnimation(keyPath: "position.x", in: view.contentView.layer)
    let endFade = try observableAnimation(keyPath: "opacity", in: view.contentView.layer)
    XCTAssertEqual(finishSlide.repeatCount, 0)
    XCTAssertEqual(
      endFade.beginTime,
      finishSlide.beginTime + finishSlide.duration,
      accuracy: 0.000_1
    )
    XCTAssertEqual(endFade.duration, 0.01, accuracy: 0.000_1)

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

    XCTAssertNil(view.contentView.layer.mask)
    XCTAssertFalse(view.isShimmering)
    window.isHidden = true
  }

  func testImmediateStopCancelsPendingSmoothCompletionSynchronously() throws {
    let (_, view) = makeVisibleView()
    view.configuration = try makeConfiguration(
      speed: 20_000,
      pauseDuration: 0,
      endFadeDuration: 0.01
    )
    view.start()
    view.stop(.smooth)

    view.stop(.immediate)

    XCTAssertNil(view.contentView.layer.mask)
    XCTAssertFalse(view.isShimmering)

    view.start()
    let restartedMask = view.contentView.layer.mask
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

    XCTAssertTrue(view.contentView.layer.mask === restartedMask)
    XCTAssertTrue(view.isShimmering)
  }

  func testRunningConfigurationChangesAtomicallyAtNextSweepBoundary() throws {
    let (window, view) = makeVisibleView()
    view.configuration = try makeConfiguration(
      speed: 20_000,
      pauseDuration: 0,
      animationOpacity: 0.5,
      beginFadeDuration: 0
    )
    view.start()
    let activeMask = try XCTUnwrap(view.contentView.layer.mask as? CAGradientLayer)

    view.configuration = try makeConfiguration(
      speed: 10_000,
      pauseDuration: 0,
      animationOpacity: 0.2,
      beginFadeDuration: 0,
      direction: .rightToLeft
    )

    XCTAssertTrue(view.contentView.layer.mask === activeMask)
    XCTAssertEqual(try centerAlpha(of: activeMask), 0.5, accuracy: 0.000_1)

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

    let updatedMask = try XCTUnwrap(view.contentView.layer.mask as? CAGradientLayer)
    let updatedSlide = try observableAnimation(keyPath: "position.x", in: updatedMask)
    XCTAssertEqual(try centerAlpha(of: updatedMask), 0.2, accuracy: 0.000_1)
    XCTAssertEqual(updatedSlide.duration, 0.01, accuracy: 0.000_1)
    XCTAssertEqual(view.configuration.direction, .rightToLeft)
    window.isHidden = true
  }

  func testStoppedConfigurationAppliesCompletelyOnNextStart() throws {
    let layer = makeLayer()
    layer.configuration = try makeConfiguration(
      speed: 1_000,
      pauseDuration: 0.25,
      animationOpacity: 0.3,
      beginFadeDuration: 0,
      direction: .bottomToTop
    )

    layer.start()

    let mask = try XCTUnwrap(layer.contentLayer.mask as? CAGradientLayer)
    let slide = try observableAnimation(keyPath: "position.x", in: mask)
    XCTAssertEqual(try centerAlpha(of: mask), 0.3, accuracy: 0.000_1)
    XCTAssertEqual(slide.duration, 0.35, accuracy: 0.000_1)
    XCTAssertEqual(layer.configuration.direction, .bottomToTop)
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
    speed: CGFloat,
    pauseDuration: CFTimeInterval,
    animationOpacity: Float = 0.5,
    beginFadeDuration: CFTimeInterval = 0.1,
    endFadeDuration: CFTimeInterval = 0.3,
    direction: ShimmerDirection = .leftToRight
  ) throws -> ShimmerConfiguration {
    try ShimmerConfiguration(
      speed: speed,
      pauseDuration: pauseDuration,
      highlightLength: 1,
      baseOpacity: 1,
      animationOpacity: animationOpacity,
      beginFadeDuration: beginFadeDuration,
      endFadeDuration: endFadeDuration,
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

  private func centerAlpha(of mask: CAGradientLayer) throws -> CGFloat {
    let colors = try XCTUnwrap(mask.colors)
    let color = colors[colors.count / 2] as! CGColor
    return color.alpha
  }
}
