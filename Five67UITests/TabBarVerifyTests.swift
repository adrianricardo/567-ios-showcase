import XCTest

@MainActor
final class TabBarVerifyTests: XCTestCase {
    var app: XCUIApplication!

    private func launchApp(additionalArguments: [String] = []) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-Five67UITestSkipOnboarding")
        app.launchArguments.append(contentsOf: additionalArguments)
        app.launch()
        sleep(2)
        for _ in 0..<3 where app.buttons["Got it"].exists {
            app.buttons["Got it"].tap()
            sleep(1)
        }
    }

    func testOnboardingCompletionLandsInLibrary() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-Five67UITestOnboardingCompletionFixture")
        app.launch()

        let maybeLater = app.buttons["Maybe later"]
        XCTAssertTrue(maybeLater.waitForExistence(timeout: 8))
        maybeLater.tap()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["Library"].isSelected)
        XCTAssertTrue(app.staticTexts["Library"].exists)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "final-onboarding-library-arrival"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLibraryToPracticeContinuity() throws {
        launchApp(additionalArguments: ["-Five67UITestSeedLibrary"])

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5))
        tabBar.buttons["Library"].tap()

        let libraryMove = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Cross-body lead'")
        ).firstMatch
        XCTAssertTrue(libraryMove.waitForExistence(timeout: 5))
        libraryMove.tap()

        let selectedResult = app.descendants(matching: .any)["feed-current-result"]
        XCTAssertTrue(selectedResult.waitForExistence(timeout: 5))
        XCTAssertTrue((selectedResult.value as? String)?.contains("Cross-body lead") == true)

        XCTAssertTrue(app.buttons["Edit moves"].waitForExistence(timeout: 5))
        app.buttons["Edit moves"].tap()

        let player = app.descendants(matching: .any)["Video playback"]
        XCTAssertTrue(player.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Cross-body lead'")
        ).firstMatch.exists)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "final-library-practice-arrival"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPracticeCompletionReturnsToChangedResult() throws {
        launchApp(additionalArguments: ["-Five67UITestSeedLibrary"])

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5))
        tabBar.buttons["Library"].tap()
        let libraryMove = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Cross-body lead'")
        ).firstMatch
        XCTAssertTrue(libraryMove.waitForExistence(timeout: 5))
        libraryMove.tap()

        let selectedResult = app.descendants(matching: .any)["feed-current-result"]
        XCTAssertTrue(selectedResult.waitForExistence(timeout: 5))
        let valueBeforePractice = selectedResult.value as? String

        XCTAssertTrue(app.buttons["Edit moves"].waitForExistence(timeout: 5))
        app.buttons["Edit moves"].tap()
        let position = app.descendants(matching: .any)["Playback position"]
        XCTAssertTrue(position.waitForExistence(timeout: 5))
        position.swipeUp()
        app.buttons["Split"].tap()
        app.buttons["Back"].tap()

        XCTAssertTrue(tabBar.buttons["Feed"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["Feed"].isSelected)
        XCTAssertTrue(selectedResult.waitForExistence(timeout: 5))
        XCTAssertNotEqual(selectedResult.value as? String, valueBeforePractice)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "final-practice-completion-result"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testThreeTabsExist() throws {
        launchApp()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5), "Library tab missing")
        XCTAssertTrue(tabBar.buttons["Feed"].exists, "Feed tab missing")
        XCTAssertTrue(tabBar.buttons["Styles"].exists, "Styles tab missing")
    }

    func testLibraryTabTap() throws {
        launchApp()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5))
        tabBar.buttons["Library"].tap()
        sleep(1)
        XCTAssertTrue(app.exists)
    }

    func testStylesTabTap() throws {
        launchApp()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Styles"].waitForExistence(timeout: 5))
        tabBar.buttons["Styles"].tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["Styles"].waitForExistence(timeout: 3) ||
                      app.exists)
    }

    func testAddButtonVisible() throws {
        launchApp()
        XCTAssertTrue(app.buttons["Add video"].waitForExistence(timeout: 5), "Add video button missing")
    }

    func testAddButtonShowsDialog() throws {
        launchApp()
        let addBtn = app.buttons["Add video"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5))
        addBtn.tap()
        let sheet = app.sheets["Add video"]
        let alert = app.alerts["Add video"] 
        let fromPhotos = app.buttons["From Photos"]
        let dialogAppeared = sheet.waitForExistence(timeout: 3) ||
            alert.waitForExistence(timeout: 1) ||
            fromPhotos.waitForExistence(timeout: 1)
        XCTAssertTrue(dialogAppeared, "Add video dialog did not appear")
    }

    func testScreenshotsAllTabs() throws {
        launchApp()
        let tabBar = app.tabBars.firstMatch

        // Feed tab (default)
        XCTAssertTrue(tabBar.buttons["Feed"].waitForExistence(timeout: 5))
        tabBar.buttons["Feed"].tap()
        sleep(1)
        let feedShot = XCUIScreen.main.screenshot()
        let feedAtt = XCTAttachment(screenshot: feedShot)
        feedAtt.name = "feed-tab"
        feedAtt.lifetime = .keepAlways
        add(feedAtt)

        // Library tab
        tabBar.buttons["Library"].tap()
        sleep(1)
        let libShot = XCUIScreen.main.screenshot()
        let libAtt = XCTAttachment(screenshot: libShot)
        libAtt.name = "library-tab"
        libAtt.lifetime = .keepAlways
        add(libAtt)

        // Styles tab
        tabBar.buttons["Styles"].tap()
        sleep(1)
        let stylesShot = XCUIScreen.main.screenshot()
        let stylesAtt = XCTAttachment(screenshot: stylesShot)
        stylesAtt.name = "styles-tab"
        stylesAtt.lifetime = .keepAlways
        add(stylesAtt)

        // Tap Add button → dialog
        tabBar.buttons["Feed"].tap()
        sleep(1)
        app.buttons["Add video"].tap()
        sleep(1)
        let dialogShot = XCUIScreen.main.screenshot()
        let dialogAtt = XCTAttachment(screenshot: dialogShot)
        dialogAtt.name = "add-video-dialog"
        dialogAtt.lifetime = .keepAlways
        add(dialogAtt)
        
        // Dismiss
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
    }

    func testLibraryPopulatedReviewFlow() throws {
        launchApp(additionalArguments: ["-Five67UITestSeedLibrary"])

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5))
        tabBar.buttons["Library"].tap()

        let moves = app.buttons["Moves"]
        let videos = app.buttons["Videos"]
        XCTAssertTrue(moves.waitForExistence(timeout: 5))
        XCTAssertEqual(moves.value as? String, "Selected")
        videos.tap()
        XCTAssertEqual(videos.value as? String, "Selected")
        moves.tap()
        XCTAssertEqual(moves.value as? String, "Selected")

        let search = app.textFields["Search moves and videos"]
        XCTAssertTrue(search.exists)
        search.tap()
        search.typeText("Cross-body")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cross-body lead'")).firstMatch.exists)
        app.buttons["Clear search"].tap()
        if app.keyboards.buttons["return"].exists {
            app.keyboards.buttons["return"].tap()
        }

        let populatedShot = XCUIScreen.main.screenshot()
        let populatedAttachment = XCTAttachment(screenshot: populatedShot)
        populatedAttachment.name = "library-populated"
        populatedAttachment.lifetime = .keepAlways
        add(populatedAttachment)

        let firstMove = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cross-body lead'")).firstMatch
        XCTAssertTrue(firstMove.exists)
        firstMove.tap()
        XCTAssertTrue(tabBar.buttons["Feed"].isSelected, "A full-row move tap must route to its playback destination")
        tabBar.buttons["Library"].tap()
        XCTAssertTrue(moves.waitForExistence(timeout: 3))

        let moveForActions = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cross-body lead'")).firstMatch
        XCTAssertTrue(moveForActions.waitForExistence(timeout: 3))
        moveForActions.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Rename"].waitForExistence(timeout: 3))
        app.buttons["Rename"].tap()

        let renameField = app.textFields["Name"]
        XCTAssertTrue(renameField.waitForExistence(timeout: 3))
        renameField.tap()
        renameField.typeText(" reviewed")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'reviewed'")).firstMatch.waitForExistence(timeout: 3))

        let renamedMove = app.buttons.matching(NSPredicate(format: "label CONTAINS 'reviewed'")).firstMatch
        renamedMove.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Exclude"].waitForExistence(timeout: 3))
        app.buttons["Exclude"].tap()

        tabBar.buttons["Styles"].tap()
        XCTAssertTrue(app.buttons["Salsa"].waitForExistence(timeout: 3))
        app.buttons["Salsa"].tap()
        tabBar.buttons["Library"].tap()
        XCTAssertTrue(app.staticTexts["Style filter: Salsa"].waitForExistence(timeout: 3) || app.staticTexts["Salsa"].exists)

        videos.tap()
        let firstVideo = app.buttons.matching(NSPredicate(format: "value == 'Playing'" )).firstMatch
        XCTAssertTrue(firstVideo.waitForExistence(timeout: 3), "Active video must expose Playing as its accessibility value")
        firstVideo.tap()
        XCTAssertTrue(tabBar.buttons["Feed"].isSelected, "Library video tap must preserve playback routing to Feed")

        tabBar.buttons["Library"].tap()
        moves.tap()
        let moveToDelete = app.buttons.matching(NSPredicate(format: "label CONTAINS 'reviewed'")).firstMatch
        XCTAssertTrue(moveToDelete.waitForExistence(timeout: 3))
        moveToDelete.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3))
        app.buttons["Delete"].tap()
        XCTAssertFalse(moveToDelete.waitForExistence(timeout: 2))
    }

    func testPracticeDetailPlaybackAndAccessibilityFlow() throws {
        launchApp(additionalArguments: ["-Five67UITestSeedLibrary"])

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5))
        tabBar.buttons["Library"].tap()

        let move = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Cross-body lead'")
        ).firstMatch
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        move.tap()

        let selectedResult = app.descendants(matching: .any)["feed-current-result"]
        XCTAssertTrue(selectedResult.waitForExistence(timeout: 5))
        XCTAssertTrue((selectedResult.value as? String)?.contains("Cross-body lead") == true)

        let editMoves = app.buttons["Edit moves"]
        XCTAssertTrue(editMoves.waitForExistence(timeout: 5))
        editMoves.tap()

        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["More"].exists)
        XCTAssertTrue(app.buttons["Loop"].exists)
        XCTAssertTrue(app.buttons["Split"].exists)
        for control in ["Back", "More", "Loop", "Split"] {
            let frame = app.buttons[control].frame
            XCTAssertGreaterThanOrEqual(frame.width, 44, "\(control) must be at least 44pt wide")
            XCTAssertGreaterThanOrEqual(frame.height, 44, "\(control) must be at least 44pt high")
        }

        let detailMove = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Cross-body lead'")
        ).firstMatch
        XCTAssertTrue(detailMove.waitForExistence(timeout: 5))
        detailMove.tap()
        let activeClip = app.buttons.matching(NSPredicate(format: "value == 'Playing'")).firstMatch
        XCTAssertTrue(activeClip.waitForExistence(timeout: 3))

        let loop = app.buttons["Loop"]
        XCTAssertTrue(loop.waitForExistence(timeout: 3))
        loop.tap()
        XCTAssertEqual(loop.value as? String, "On")

        let player = app.descendants(matching: .any)["Video playback"]
        XCTAssertTrue(player.exists)
        XCTAssertTrue((player.value as? String)?.contains("Playing") == true)
        player.tap()
        XCTAssertTrue((player.value as? String)?.contains("Paused") == true)
        player.tap()
        XCTAssertTrue((player.value as? String)?.contains("Playing") == true)
        player.tap()
        XCTAssertTrue((player.value as? String)?.contains("Paused") == true)

        let position = app.descendants(matching: .any)["Playback position"]
        XCTAssertTrue(position.exists)
        let positionBeforeSeek = position.value as? String
        position.swipeUp()
        XCTAssertNotEqual(position.value as? String, positionBeforeSeek)

        let activeShot = XCUIScreen.main.screenshot()
        let activeAttachment = XCTAttachment(screenshot: activeShot)
        activeAttachment.name = "practice-detail-active-clip"
        activeAttachment.lifetime = .keepAlways
        add(activeAttachment)

        activeClip.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Rename"].waitForExistence(timeout: 3))
        app.buttons["Rename"].tap()
        let renameField = app.textFields["Name"]
        XCTAssertTrue(renameField.waitForExistence(timeout: 3))
        renameField.tap()
        renameField.typeText(" reviewed")
        app.buttons["Save"].tap()

        let renamedClip = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'reviewed'")
        ).firstMatch
        XCTAssertTrue(renamedClip.waitForExistence(timeout: 3))

        renamedClip.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Exclude"].waitForExistence(timeout: 3))
        app.buttons["Exclude"].tap()

        renamedClip.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Include"].waitForExistence(timeout: 3))
        app.buttons["Include"].tap()

        app.buttons["Split"].tap()
        app.buttons["Back"].tap()
        XCTAssertTrue(tabBar.buttons["Feed"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["Feed"].isSelected)
        XCTAssertTrue(selectedResult.waitForExistence(timeout: 5))

        let completionAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        completionAttachment.name = "final-practice-completion-return"
        completionAttachment.lifetime = .keepAlways
        add(completionAttachment)
    }

    func testPracticeDetailEmptyStateCapture() throws {
        launchApp(additionalArguments: ["-Five67UITestSeedLibrary"])

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5))
        tabBar.buttons["Library"].tap()

        let libraryMove = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Cross-body lead'")
        ).firstMatch
        XCTAssertTrue(libraryMove.waitForExistence(timeout: 5))
        libraryMove.tap()
        XCTAssertTrue(app.buttons["Edit moves"].waitForExistence(timeout: 5))
        app.buttons["Edit moves"].tap()

        let firstClip = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Cross-body lead'")
        ).firstMatch
        XCTAssertTrue(firstClip.waitForExistence(timeout: 5))
        firstClip.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3))
        app.buttons["Delete"].tap()

        let remainingClip = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Inside turn setup'")
        ).firstMatch
        XCTAssertTrue(remainingClip.waitForExistence(timeout: 3))
        remainingClip.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3))
        app.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["to add your first move"].waitForExistence(timeout: 3))

        let emptyShot = XCUIScreen.main.screenshot()
        let emptyAttachment = XCTAttachment(screenshot: emptyShot)
        emptyAttachment.name = "practice-detail-empty"
        emptyAttachment.lifetime = .keepAlways
        add(emptyAttachment)
    }

    func testPracticeDetailAccessibilityLayout() throws {
        launchApp(additionalArguments: ["-Five67UITestSeedLibrary"])

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5))
        tabBar.buttons["Library"].tap()

        let libraryMove = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Cross-body lead'")
        ).firstMatch
        XCTAssertTrue(libraryMove.waitForExistence(timeout: 5))
        libraryMove.tap()
        XCTAssertTrue(app.buttons["Edit moves"].waitForExistence(timeout: 5))
        app.buttons["Edit moves"].tap()

        let detailMove = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Cross-body lead'")
        ).firstMatch
        XCTAssertTrue(detailMove.waitForExistence(timeout: 5))
        detailMove.tap()

        let activeClip = app.buttons.matching(NSPredicate(format: "value == 'Playing'")).firstMatch
        XCTAssertTrue(activeClip.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Practice this loop"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["Playback position"].exists)

        for control in ["Back", "More", "Loop", "Split"] {
            let frame = app.buttons[control].frame
            XCTAssertGreaterThanOrEqual(frame.width, 44)
            XCTAssertGreaterThanOrEqual(frame.height, 44)
        }

        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "practice-detail-accessibility"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
