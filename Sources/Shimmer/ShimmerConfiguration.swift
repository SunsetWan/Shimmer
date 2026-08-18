import QuartzCore

public enum ShimmerConfigurationParameter: String, Sendable {
  case speed
  case pauseDuration
  case highlightLength
  case baseOpacity
  case animationOpacity
  case beginFadeDuration
  case endFadeDuration
}

public enum ShimmerDirection: Equatable, Sendable {
  case leftToRight
  case rightToLeft
  case topToBottom
  case bottomToTop
}

public enum ShimmerConfigurationError: Error, Equatable, Sendable {
  case notFinite(ShimmerConfigurationParameter)
  case mustBePositive(ShimmerConfigurationParameter)
  case mustBeNonnegative(ShimmerConfigurationParameter)
  case outsideUnitInterval(ShimmerConfigurationParameter)
}

public struct ShimmerConfiguration: Equatable, Sendable {
  public static let `default` = ShimmerConfiguration(
    validatedSpeed: 230,
    pauseDuration: 0.4,
    highlightLength: 1,
    baseOpacity: 1,
    animationOpacity: 0.5,
    beginFadeDuration: 0.1,
    endFadeDuration: 0.3,
    direction: .leftToRight
  )

  public let speed: CGFloat
  public let pauseDuration: CFTimeInterval
  public let highlightLength: CGFloat
  public let baseOpacity: Float
  public let animationOpacity: Float
  public let beginFadeDuration: CFTimeInterval
  public let endFadeDuration: CFTimeInterval
  public let direction: ShimmerDirection

  public init(
    speed: CGFloat,
    pauseDuration: CFTimeInterval,
    highlightLength: CGFloat,
    baseOpacity: Float,
    animationOpacity: Float,
    beginFadeDuration: CFTimeInterval,
    endFadeDuration: CFTimeInterval,
    direction: ShimmerDirection
  ) throws {
    try Self.validateFinite(speed, parameter: .speed)
    guard speed > 0 else {
      throw ShimmerConfigurationError.mustBePositive(.speed)
    }

    try Self.validateNonnegative(pauseDuration, parameter: .pauseDuration)
    try Self.validateUnitInterval(highlightLength, parameter: .highlightLength)
    try Self.validateUnitInterval(baseOpacity, parameter: .baseOpacity)
    try Self.validateUnitInterval(animationOpacity, parameter: .animationOpacity)
    try Self.validateNonnegative(beginFadeDuration, parameter: .beginFadeDuration)
    try Self.validateNonnegative(endFadeDuration, parameter: .endFadeDuration)

    self.init(
      validatedSpeed: speed,
      pauseDuration: pauseDuration,
      highlightLength: highlightLength,
      baseOpacity: baseOpacity,
      animationOpacity: animationOpacity,
      beginFadeDuration: beginFadeDuration,
      endFadeDuration: endFadeDuration,
      direction: direction
    )
  }

  private init(
    validatedSpeed speed: CGFloat,
    pauseDuration: CFTimeInterval,
    highlightLength: CGFloat,
    baseOpacity: Float,
    animationOpacity: Float,
    beginFadeDuration: CFTimeInterval,
    endFadeDuration: CFTimeInterval,
    direction: ShimmerDirection
  ) {
    self.speed = speed
    self.pauseDuration = pauseDuration
    self.highlightLength = highlightLength
    self.baseOpacity = baseOpacity
    self.animationOpacity = animationOpacity
    self.beginFadeDuration = beginFadeDuration
    self.endFadeDuration = endFadeDuration
    self.direction = direction
  }

  private static func validateFinite<T: BinaryFloatingPoint>(
    _ value: T,
    parameter: ShimmerConfigurationParameter
  ) throws {
    guard value.isFinite else {
      throw ShimmerConfigurationError.notFinite(parameter)
    }
  }

  private static func validateNonnegative<T: BinaryFloatingPoint>(
    _ value: T,
    parameter: ShimmerConfigurationParameter
  ) throws {
    try validateFinite(value, parameter: parameter)
    guard value >= 0 else {
      throw ShimmerConfigurationError.mustBeNonnegative(parameter)
    }
  }

  private static func validateUnitInterval<T: BinaryFloatingPoint>(
    _ value: T,
    parameter: ShimmerConfigurationParameter
  ) throws {
    try validateFinite(value, parameter: parameter)
    guard (0...1).contains(value) else {
      throw ShimmerConfigurationError.outsideUnitInterval(parameter)
    }
  }
}
