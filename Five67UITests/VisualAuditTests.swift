import XCTest

/// Captures the surfaces whose *appearance* P3 and P5 changed but could not
/// verify: the compact sheets, the red swipe-delete glyph, the neutral Quiet
/// Stage tokens, and the typography-only paywall.
///
/// `xcrun simctl io booted screenshot` is unreliable in this project — it keeps
/// returning a stale system prompt instead of the app under test — so the
/// screenshots are taken in-process and attached to the test result. Export
/// them with:
///
///     xcrun xcresulttool export attachments \
///       --path <result>.xcresult --output-path <dir>
///
/// Run under Increase Contrast (`xcrun simctl ui booted increase_contrast
/// enabled`) to confirm boundaries come back where `Theme.stageBoundary`
/// promises they will.
@MainActor
final class VisualAuditTests: XCTestCase {
    var app: XCUIApplication!

    private func launchApp(additionalArguments: [String] = []) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-Five67UITestSkipOnboarding")
        app.launchArguments.append("-Five67UITestFreeAccess")
        app.launchArguments.append(contentsOf: additionalArguments)
        app.launch()
        sleep(2)
        for _ in 0..<3 where app.buttons["Got it"].exists {
            app.buttons["Got it"].tap()
            sleep(1)
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Library rows, the style chip, the quick-style sheet, the add-video
    /// sheet, the delete sheet, and the swipe-delete glyph.
    func testCaptureLibraryAndSheetSurfaces() throws {
        launchApp(additionalArguments: ["-Five67UITestSeedLibrary"])

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5))
        tabBar.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["Style filter"].waitForExistence(timeout: 5))
        sleep(1)
        capture("audit-01-library-moves")

        let move = app.buttons
            .matching(NSPredicate(format: "label CONTAINS 'Cross-body lead'"))
            .firstMatch
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        move.swipeLeft()
        sleep(1)
        capture("audit-02-move-swipe-delete-glyph")
        app.tap()

        app.buttons["Style filter"].tap()
        XCTAssertTrue(app.buttons["All styles"].waitForExistence(timeout: 3))
        sleep(1)
        capture("audit-03-quick-style-sheet")
        app.buttons["All styles"].tap()

        let videos = app.buttons["Videos"]
        XCTAssertTrue(videos.waitForExistence(timeout: 5))
        videos.tap()
        sleep(1)
        capture("audit-04-library-videos")

        let videoRow = app.buttons
            .matching(NSPredicate(format: "label CONTAINS 'Studio 22 practice'"))
            .firstMatch
        XCTAssertTrue(videoRow.waitForExistence(timeout: 5))
        videoRow.swipeLeft()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3))
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Delete this video?"].waitForExistence(timeout: 3))
        sleep(1)
        capture("audit-05-video-delete-sheet")
        app.buttons["Cancel"].tap()

        tabBar.buttons["Styles"].tap()
        XCTAssertTrue(app.buttons["Bachata"].waitForExistence(timeout: 5))
        sleep(1)
        capture("audit-06-styles-tab")

        tabBar.buttons["Feed"].tap()
        let addVideo = app.buttons["Add video"]
        XCTAssertTrue(addVideo.waitForExistence(timeout: 5))
        addVideo.tap()
        XCTAssertTrue(app.buttons["From Photos"].waitForExistence(timeout: 3))
        sleep(1)
        capture("audit-07-add-video-sheet")
    }

    /// The typography-only paywall, reached through the real video-cap trigger.
    func testCapturePaywall() throws {
        launchApp(additionalArguments: ["-Five67UITestVideoCapFixture"])

        let addVideo = app.buttons["Add video"]
        XCTAssertTrue(addVideo.waitForExistence(timeout: 5))
        addVideo.tap()
        XCTAssertTrue(app.buttons["From Photos"].waitForExistence(timeout: 3))
        app.buttons["From Photos"].tap()

        XCTAssertTrue(app.staticTexts["Unlock unlimited videos & styles."].waitForExistence(timeout: 5))
        sleep(1)
        capture("audit-08-paywall-video-cap")
    }

    /// The onboarding hook and its primary action — the one surface allowed to
    /// spend the pure-white action fill.
    func testCaptureOnboardingHook() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-Five67UITestReviewOnboarding")
        app.launchArguments.append("-Five67UITestFreeAccess")
        app.launch()
        sleep(3)
        capture("audit-09-onboarding-hook")
    }
}
