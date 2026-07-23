import SwiftUI

/// App-wide semantic type roles. These stay on Dynamic Type text styles so
/// hierarchy remains consistent without freezing user-facing text to points.
enum Typography {
    /// Major, friendly page and flow titles use the approved rounded system face.
    static let screenTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)

    /// Compact title over immersive video; intentionally quieter than a page title.
    static let immersiveTitle = Font.title3.weight(.bold)

    /// Reusable title for cards, sheets, coach beats, and other local sections.
    static let sectionTitle = Font.title3.weight(.bold)
}
