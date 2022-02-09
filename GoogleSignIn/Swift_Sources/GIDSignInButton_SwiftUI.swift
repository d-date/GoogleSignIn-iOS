/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import SwiftUI
import GoogleSignIn
import CoreGraphics

@available(iOS 13.0, *)
fileprivate struct Width {
  let min, max: CGFloat
}

@available(iOS 13.0, *)
extension GIDSignInButtonStyle {
  fileprivate var width: Width {
    switch self {
    case .wide: return Width(min: CGFloat(kIconWidth), max: CGFloat(kIconWidth))
    case .standard: return Width(min: 90, max: .infinity)
    case .iconOnly: return Width(min: 170, max: .infinity)
    default:
      fatalError("Unrecognized case for `GIDSignInButtonStyle: \(self)")
    }
  }

  fileprivate var buttonText: String {
    switch self {
    case .wide: return "Sign in with Google"
    case .standard: return "Sign in"
    case .iconOnly: return ""
    default:
      fatalError("Unrecognized case for `GIDSignInButtonStyle: \(self)")
    }
  }
}

@available(iOS 13.0, *)
struct SwiftUIButtonStyle: ButtonStyle {
  let style: GIDSignInButtonStyle

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(minWidth: style.width.min,
             maxWidth: style.width.max,
             minHeight: CGFloat(kButtonHeight),
             maxHeight: CGFloat(kButtonHeight))
      .foregroundColor(.blue)
      .background(Color.white)
      .cornerRadius(5)
      .shadow(color: .gray, radius: 2, x: 0, y: 2)
  }
}

/// A Google Sign In button to be used in SwiftUI.
@available(iOS 13.0, *)
public struct GIDSwiftUISignInButton: View {
  private let googleImageName = "google"
  private let action: () -> Void

  // MARK: - Button attribute wrappers

  @ObservedObject private var styleWrapper: GIDSignInButtonStyleWrapper
  /// The `GIDSignInButtonStyle` for the button.
  public var style: GIDSignInButtonStyle {
    set {
      styleWrapper.wrapped = newValue
    }
    get {
      return styleWrapper.wrapped
    }
  }

  @ObservedObject private var colorSchemeWrapper: GIDSignInButtonColorSchemeWrapper
  /// The `GIDSignInButtonColorScheme` for the button.
  public var colorScheme: GIDSignInButtonColorScheme {
    set {
      colorSchemeWrapper.wrapped = newValue
    }
    get {
      return colorSchemeWrapper.wrapped
    }
  }

  @ObservedObject private var stateWrapper: GIDSignInButtonStateWrapper
  /// The `GIDSignInButtonState` for the button.
  public var state: GIDSignInButtonState {
    set {
      stateWrapper.wrapped = newValue
    }
    get {
      return stateWrapper.wrapped
    }
  }

  /// Creates an instance of the Google Sign-In button for use in SwiftUI
  /// - parameter style: The button style to use.
  /// - parameter colorScheme: The color scheme for the button.
  /// - parameter state: The button's state to use.
  /// - parameter action: A closure to use as the button's action upon press.
  public init(
    style: GIDSignInButtonStyle = .standard,
    colorScheme: GIDSignInButtonColorScheme = .light,
    state: GIDSignInButtonState = .normal,
    action: @escaping () -> Void
  ) {
    self.styleWrapper = GIDSignInButtonStyleWrapper(wrapped: style)
    self.colorSchemeWrapper = GIDSignInButtonColorSchemeWrapper(wrapped: colorScheme)
    self.stateWrapper = GIDSignInButtonStateWrapper(wrapped: state)
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      switch style {
      case .iconOnly:
        Image("google", bundle: Bundle.gidFrameworkPath())
      case .standard, .wide:
        HStack {
          Image("google", bundle: Bundle.gidFrameworkPath())
            .padding(.leading, 8)
          Text(style.buttonText)
            .padding(.trailing, 8)
          Spacer()
        }
      default:
        fatalError("Unrecognized case for `GIDSignInButtonStyle: \(self)")
      }
    }
    .buttonStyle(SwiftUIButtonStyle(style: style))
  }

  private func iconImage() -> UIImage? {
    guard let bundle = Bundle.gidFrameworkPath(), let path = bundle.path(
      forResource: googleImageName,
      ofType: "png") else {
        return nil
      }
    let image = UIImage(contentsOfFile: path)

    switch state {
    case .disabled:
      return image?.imageWithBlendMode(
        .multiply,
        color: .init(white: 0, alpha: kDisabledIconAlpha)
      )
    default:
      return image
    }
  }
}

@available(iOS 13.0, *)
private extension UIImage {
  func imageWithBlendMode(_ blendMode: CGBlendMode, color: UIColor) -> UIImage? {
    var color = color
    let size: CGSize = self.size
    let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)

    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
    let context = UIGraphicsGetCurrentContext()
    context?.setShouldAntialias(true)
    context?.interpolationQuality = .high
    context?.scaleBy(x: 1, y: -1)
    context?.translateBy(x: 0, y: -rect.size.height)
    // FIXME: Do not force unwrap the cgImage below.
    context?.clip(to: rect, mask: self.cgImage!)
    context?.draw(self.cgImage!.self, in: rect)
    context?.setBlendMode(blendMode)

    var alpha: CGFloat = 1.0
    if blendMode == .multiply {
      var red: CGFloat = 0
      var green: CGFloat = 0
      var blue: CGFloat = 0
      let colorsRetrieved = color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
      if colorsRetrieved {
        color = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
      } else {
        var grayscale: CGFloat = 0
        let whiteRetrieved = color.getWhite(&grayscale, alpha: &alpha)
        if whiteRetrieved {
          color = UIColor(white: grayscale, alpha: 1.0)
        }
      }
    }

    context?.setFillColor(color.cgColor)
    context?.fill(rect)

    if blendMode == .multiply && alpha != 1.0 {
      // Modulate by the alpha.
      color = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: alpha)
      context?.setBlendMode(.destinationIn)
      context?.setFillColor(color.cgColor)
      context?.fill(rect)
    }

    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    if self.capInsets.bottom > 0 || self.capInsets.top > 0 ||
        self.capInsets.left > 0 || self.capInsets.left > 0 {
      image?.resizableImage(withCapInsets: self.capInsets)
    }

    return image
  }

}

private extension Bundle {
  class func gidFrameworkPath() -> Bundle? {
    if let path = Bundle.main.path(
      forResource: "GoogleSignIn_GoogleSignIn",
      ofType: "bundle"
    ) {
      return Bundle(path: path)
    } else if let otherPath = Bundle(for: GIDSignIn.self).path(
      forResource: "GoogleSignIn_GoogleSignIn",
      ofType: "bundle") {
      return Bundle(path: otherPath)
    } else {
      return nil
    }
  }
}
