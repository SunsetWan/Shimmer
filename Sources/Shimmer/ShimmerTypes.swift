import QuartzCore

public enum ShimmerStopMode: Sendable {
  case smooth
  case immediate
}

public struct ShimmerStartTime: Hashable, Sendable {
  let mediaTime: CFTimeInterval

  public static var now: Self {
    Self(mediaTime: CACurrentMediaTime())
  }
}
