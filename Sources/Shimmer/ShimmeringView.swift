import UIKit

@MainActor
public final class ShimmeringView: UIView {
  public let contentView: UIView

  private let shimmerEngine: ShimmerEngine

  public var configuration: ShimmerConfiguration {
    get { shimmerEngine.configuration }
    set { shimmerEngine.configuration = newValue }
  }

  public var isShimmering: Bool {
    shimmerEngine.isShimmering
  }

  public override init(frame: CGRect) {
    let contentView = UIView()
    self.contentView = contentView
    shimmerEngine = ShimmerEngine(contentLayer: contentView.layer)
    super.init(frame: frame)
    addSubview(contentView)
  }

  public required init?(coder: NSCoder) {
    let contentView = UIView()
    self.contentView = contentView
    shimmerEngine = ShimmerEngine(contentLayer: contentView.layer)
    super.init(coder: coder)
    addSubview(contentView)
  }

  public func start(at startTime: ShimmerStartTime = .now) {
    shimmerEngine.start(at: startTime)
    if window == nil {
      shimmerEngine.pause()
    }
  }

  public func stop(_ mode: ShimmerStopMode = .smooth) {
    shimmerEngine.stop(mode)
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    contentView.frame = bounds
    shimmerEngine.layoutDidChange()
  }

  public override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      shimmerEngine.pause()
    } else {
      shimmerEngine.resume()
    }
  }
}
