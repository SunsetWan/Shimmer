import UIKit
import XCTest

@testable import Shimmer

@MainActor
final class ShimmeringViewTests: XCTestCase {
  func testContentViewIsStableAndHostsRealUIKitContent() {
    let view = ShimmeringView(frame: CGRect(x: 0, y: 0, width: 240, height: 80))
    let contentView = view.contentView
    let label = UILabel()
    label.text = "Loading"
    contentView.addSubview(label)

    view.layoutIfNeeded()
    view.start()

    XCTAssertTrue(view.contentView === contentView)
    XCTAssertTrue(contentView.superview === view)
    XCTAssertTrue(label.superview === contentView)
    XCTAssertNotNil(contentView.layer.mask)
  }

  func testImmediateStopPreservesContentAndOuterViewMask() {
    let view = ShimmeringView(frame: CGRect(x: 0, y: 0, width: 240, height: 80))
    let label = UILabel()
    view.contentView.addSubview(label)
    let outerMask = CALayer()
    view.layer.mask = outerMask
    view.layoutIfNeeded()
    view.start()

    view.stop(.immediate)

    XCTAssertNil(view.contentView.layer.mask)
    XCTAssertTrue(view.layer.mask === outerMask)
    XCTAssertTrue(label.superview === view.contentView)
    XCTAssertFalse(view.isShimmering)
  }
}
