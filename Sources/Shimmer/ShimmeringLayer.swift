import QuartzCore

@MainActor
public final class ShimmeringLayer: CALayer {
  public private(set) lazy var contentLayer: CALayer = {
    let contentLayer = CALayer()
    contentLayer.frame = bounds
    addSublayer(contentLayer)
    return contentLayer
  }()

  private lazy var shimmerEngine = ShimmerEngine(contentLayer: contentLayer)

  public var configuration: ShimmerConfiguration {
    get { shimmerEngine.configuration }
    set { shimmerEngine.configuration = newValue }
  }

  public var isShimmering: Bool {
    shimmerEngine.isShimmering
  }

  public override init() {
    super.init()
  }

  public override init(layer: Any) {
    super.init(layer: layer)
  }

  public required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  public func start(at startTime: ShimmerStartTime = .now) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    contentLayer.frame = bounds
    CATransaction.commit()
    shimmerEngine.start(at: startTime)
  }

  public func stop(_ mode: ShimmerStopMode = .smooth) {
    shimmerEngine.stop(mode)
  }
}
