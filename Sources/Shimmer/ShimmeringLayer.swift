import UIKit

@MainActor
public final class ShimmeringLayer: CALayer {
  public private(set) lazy var contentLayer: CALayer = {
    let contentLayer = CALayer()
    contentLayer.frame = bounds
    addSublayer(contentLayer)
    return contentLayer
  }()

  private lazy var shimmerEngine = ShimmerEngine(contentLayer: contentLayer)
  private var geometryDisplayLink: CADisplayLink?

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
    synchronizeContentLayout()
    shimmerEngine.start(at: startTime)
    startGeometryObservation()
  }

  public func stop(_ mode: ShimmerStopMode = .smooth) {
    shimmerEngine.stop(mode)
    stopGeometryObservation()
  }

  private func startGeometryObservation() {
    guard geometryDisplayLink == nil else { return }
    let target = ShimmeringLayerDisplayLinkTarget(layer: self)
    let displayLink = CADisplayLink(
      target: target,
      selector: #selector(ShimmeringLayerDisplayLinkTarget.tick(_:))
    )
    displayLink.add(to: .main, forMode: .common)
    geometryDisplayLink = displayLink
  }

  private func stopGeometryObservation() {
    geometryDisplayLink?.invalidate()
    geometryDisplayLink = nil
  }

  fileprivate func synchronizeContentLayout() {
    if contentLayer.frame != bounds {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      contentLayer.frame = bounds
      CATransaction.commit()
    }
    shimmerEngine.layoutDidChange()
  }
}

@MainActor
private final class ShimmeringLayerDisplayLinkTarget: NSObject {
  weak var layer: ShimmeringLayer?

  init(layer: ShimmeringLayer) {
    self.layer = layer
  }

  @objc func tick(_ displayLink: CADisplayLink) {
    guard let layer else {
      displayLink.invalidate()
      return
    }
    layer.synchronizeContentLayout()
  }
}
