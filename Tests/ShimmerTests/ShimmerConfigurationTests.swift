import QuartzCore
import XCTest

@testable import Shimmer

final class ShimmerConfigurationTests: XCTestCase {
  func testDefaultsPreserveOriginalVisualIntent() {
    let configuration = ShimmerConfiguration.default

    XCTAssertEqual(configuration.speed, 230)
    XCTAssertEqual(configuration.pauseDuration, 0.4)
    XCTAssertEqual(configuration.highlightLength, 1)
    XCTAssertEqual(configuration.baseOpacity, 1)
    XCTAssertEqual(configuration.animationOpacity, 0.5)
    XCTAssertEqual(configuration.beginFadeDuration, 0.1)
    XCTAssertEqual(configuration.endFadeDuration, 0.3)
  }

  func testConfigurationIsSendable() {
    requireSendable(ShimmerConfiguration.self)
  }

  func testRejectsInvalidValuesWithTypedErrors() throws {
    XCTAssertThrowsError(
      try makeConfiguration(speed: .infinity)
    ) { error in
      XCTAssertEqual(error as? ShimmerConfigurationError, .notFinite(.speed))
    }
    XCTAssertThrowsError(
      try makeConfiguration(speed: -1)
    ) { error in
      XCTAssertEqual(error as? ShimmerConfigurationError, .mustBePositive(.speed))
    }
    XCTAssertThrowsError(
      try makeConfiguration(pauseDuration: -0.1)
    ) { error in
      XCTAssertEqual(error as? ShimmerConfigurationError, .mustBeNonnegative(.pauseDuration))
    }
    XCTAssertThrowsError(
      try makeConfiguration(highlightLength: 1.1)
    ) { error in
      XCTAssertEqual(error as? ShimmerConfigurationError, .outsideUnitInterval(.highlightLength))
    }
    XCTAssertThrowsError(
      try makeConfiguration(animationOpacity: .nan)
    ) { error in
      XCTAssertEqual(error as? ShimmerConfigurationError, .notFinite(.animationOpacity))
    }
    XCTAssertThrowsError(
      try makeConfiguration(baseOpacity: 1.1)
    ) { error in
      XCTAssertEqual(error as? ShimmerConfigurationError, .outsideUnitInterval(.baseOpacity))
    }
    XCTAssertThrowsError(
      try makeConfiguration(beginFadeDuration: -0.1)
    ) { error in
      XCTAssertEqual(error as? ShimmerConfigurationError, .mustBeNonnegative(.beginFadeDuration))
    }
    XCTAssertThrowsError(
      try makeConfiguration(endFadeDuration: -.infinity)
    ) { error in
      XCTAssertEqual(error as? ShimmerConfigurationError, .notFinite(.endFadeDuration))
    }
  }

  private func makeConfiguration(
    speed: CGFloat = 230,
    pauseDuration: CFTimeInterval = 0.4,
    highlightLength: CGFloat = 1,
    baseOpacity: Float = 1,
    animationOpacity: Float = 0.5,
    beginFadeDuration: CFTimeInterval = 0.1,
    endFadeDuration: CFTimeInterval = 0.3
  ) throws -> ShimmerConfiguration {
    try ShimmerConfiguration(
      speed: speed,
      pauseDuration: pauseDuration,
      highlightLength: highlightLength,
      baseOpacity: baseOpacity,
      animationOpacity: animationOpacity,
      beginFadeDuration: beginFadeDuration,
      endFadeDuration: endFadeDuration
    )
  }

  private func requireSendable<T: Sendable>(_: T.Type) {}
}
