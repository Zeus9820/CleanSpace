import AppKit
import XCTest

final class AccessibilityContrastTests: XCTestCase {
    func testSystemTextSurfacesMeetContrastThresholdsInSupportedAppearances() {
        let appearances: [NSAppearance.Name] = [
            .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua
        ]

        for appearanceName in appearances {
            let appearance = NSAppearance(named: appearanceName)!
            appearance.performAsCurrentDrawingAppearance {
                let background = NSColor.windowBackgroundColor
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(NSColor.labelColor, background), 4.5,
                    "Primary labels must remain legible in \(appearanceName.rawValue)"
                )
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(NSColor.secondaryLabelColor, background), 3.0,
                    "Secondary explanatory text must remain legible in \(appearanceName.rawValue)"
                )
            }
        }
    }

    private func contrastRatio(_ first: NSColor, _ second: NSColor) -> Double {
        let firstLuminance = relativeLuminance(first)
        let secondLuminance = relativeLuminance(second)
        return (max(firstLuminance, secondLuminance) + 0.05)
            / (min(firstLuminance, secondLuminance) + 0.05)
    }

    private func relativeLuminance(_ color: NSColor) -> Double {
        let rgb = color.usingColorSpace(.sRGB)!
        return [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
            .map { component in
                let value = Double(component)
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            .enumerated()
            .reduce(0) { result, entry in
                result + entry.element * [0.2126, 0.7152, 0.0722][entry.offset]
            }
    }
}
