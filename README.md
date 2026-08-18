# Shimmer

Shimmer adds a Core Animation loading effect to UIKit views and layers. Version 2 is a Swift 6 package for iOS 13 and later.

![Shimmer](shimmer.gif)

## Installation

Add `https://github.com/SunsetWan/Shimmer` as a Swift Package dependency and select the `Shimmer` product. To pin the first v2 release in `Package.swift`:

```swift
.package(
  url: "https://github.com/SunsetWan/Shimmer",
  exact: "2.0.0"
)
```

Then import the module:

```swift
import Shimmer
```

## ShimmeringView

`ShimmeringView` owns a `contentView`. Add placeholder subviews to that content view, then start the effect:

```swift
let shimmerView = ShimmeringView(frame: view.bounds)
view.addSubview(shimmerView)

let placeholder = UIView(frame: shimmerView.bounds)
placeholder.backgroundColor = .secondarySystemBackground
shimmerView.contentView.addSubview(placeholder)

shimmerView.start()
```

The view pauses its underlying animation when it leaves a window while preserving `isShimmering`. Reattaching it resumes from its original timeline. An immediate stop prevents later reattachment from restarting it.

## ShimmeringLayer

`ShimmeringLayer` owns a `contentLayer`. Add layer content there and let the caller decide when visibility changes require `start(at:)` or `stop(_:)`:

```swift
let shimmerLayer = ShimmeringLayer()
shimmerLayer.frame = hostLayer.bounds
hostLayer.addSublayer(shimmerLayer)
shimmerLayer.contentLayer.addSublayer(placeholderLayer)
shimmerLayer.start()
```

Both hosts expose `configuration`, `isShimmering`, `start(at:)`, and `stop(_:)`. They keep their content host stable while managing only its mask.

## Configuration

Use `.default` or construct a validated configuration:

```swift
shimmerView.configuration = try ShimmerConfiguration(
  speed: 230,
  pauseDuration: 0.4,
  highlightLength: 1,
  baseOpacity: 1,
  animationOpacity: 0.5,
  beginFadeDuration: 0.1,
  endFadeDuration: 0.3,
  direction: .leftToRight
)
```

Directions are physical: `.leftToRight`, `.rightToLeft`, `.topToBottom`, and `.bottomToTop`. Invalid numeric values throw `ShimmerConfigurationError`.

## Shared timelines

Reuse one opaque start time to keep independent hosts in phase:

```swift
let startTime = ShimmerStartTime.now
firstShimmer.start(at: startTime)
secondShimmer.start(at: startTime)
```

The package preserves that timeline through zero-sized starts, bounds changes, and `ShimmeringView` remounts without exposing raw Core Animation timing values.

## Stopping

```swift
shimmerView.stop(.smooth)
shimmerView.stop(.immediate)
```

- `.smooth` finishes the current sweep and end fade before removing the mask.
- `.immediate` synchronously removes all shimmer resources.

Repeated starts and stops are idempotent.

## Migrating from v1

Version 2 is a breaking Swift-only release:

- Replace `FBShimmeringView` and `FBShimmeringLayer` with `ShimmeringView` and `ShimmeringLayer`.
- Replace the `shimmering` Boolean property with `start(at:)` and `stop(_:)`.
- Configure the effect with `ShimmerConfiguration` instead of Objective-C properties.
- Integrate with Swift Package Manager. CocoaPods, copied-source, Objective-C, and binary compatibility are not provided.
- The minimum deployment target is iOS 13, and clients compile the package in Swift 6 language mode.

## License

Shimmer is available under the BSD license in [LICENSE](LICENSE).
