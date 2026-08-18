import QuartzCore
import XCTest

@testable import Shimmer

@MainActor
final class ShimmeringLayerTests: XCTestCase {
  func testContentLayerIsStableAndFillsBounds() {
    let layer = ShimmeringLayer()
    layer.bounds = CGRect(x: 0, y: 0, width: 240, height: 80)
    let contentLayer = layer.contentLayer

    layer.layoutIfNeeded()

    XCTAssertTrue(layer.contentLayer === contentLayer)
    XCTAssertTrue(contentLayer.superlayer === layer)
    XCTAssertEqual(contentLayer.frame, layer.bounds)
  }

  func testDefaultStartInstallsOneLeftToRightAlphaMaskSweep() throws {
    let layer = ShimmeringLayer()
    layer.bounds = CGRect(x: 0, y: 0, width: 240, height: 80)
    layer.layoutIfNeeded()

    layer.start()

    let mask = try XCTUnwrap(layer.contentLayer.mask as? CAGradientLayer)
    let animationKey = try XCTUnwrap(mask.animationKeys()?.only)
    let animation = try XCTUnwrap(mask.animation(forKey: animationKey) as? CABasicAnimation)
    XCTAssertEqual(animation.keyPath, "position.x")
    XCTAssertLessThan(try XCTUnwrap(animation.fromValue as? CGFloat), 0)
    XCTAssertEqual(try XCTUnwrap(animation.toValue as? CGFloat), 0)
    XCTAssertEqual(animation.repeatCount, .infinity)
    XCTAssertEqual(mask.colors?.count, 3)
    XCTAssertTrue(layer.isShimmering)
  }

  func testImmediateStopSynchronouslyRemovesInternalMaskAndPreservesOuterMask() {
    let layer = ShimmeringLayer()
    let outerMask = CALayer()
    layer.mask = outerMask
    layer.bounds = CGRect(x: 0, y: 0, width: 240, height: 80)
    layer.layoutIfNeeded()
    layer.start()

    layer.stop(.immediate)

    XCTAssertFalse(layer.isShimmering)
    XCTAssertNil(layer.contentLayer.mask)
    XCTAssertTrue(layer.mask === outerMask)
  }

  func testRepeatedStartAndImmediateStopAreIdempotent() {
    let layer = ShimmeringLayer()
    layer.bounds = CGRect(x: 0, y: 0, width: 240, height: 80)
    layer.layoutIfNeeded()

    layer.start()
    let firstMask = layer.contentLayer.mask
    let firstAnimationBeginTime = firstMask?
      .animationKeys()?
      .compactMap { firstMask?.animation(forKey: $0) }
      .first?
      .beginTime
    layer.start()

    XCTAssertTrue(layer.contentLayer.mask === firstMask)
    let repeatedAnimationBeginTime = layer.contentLayer.mask?
      .animationKeys()?
      .compactMap { layer.contentLayer.mask?.animation(forKey: $0) }
      .first?
      .beginTime
    XCTAssertEqual(repeatedAnimationBeginTime, firstAnimationBeginTime)

    layer.stop(.immediate)
    layer.stop(.immediate)

    XCTAssertNil(layer.contentLayer.mask)
    XCTAssertFalse(layer.isShimmering)
  }
}

extension Collection {
  fileprivate var only: Element? {
    count == 1 ? first : nil
  }
}
