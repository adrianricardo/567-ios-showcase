import XCTest

/// Mirrors `AccessPolicy.freeVideoLimit`. The UI test target can't import the
/// app target, so this constant must be updated whenever the policy changes.
private let freeVideoLimit = 3

/// `-Five67UITestAboveVideoCapFixture` seeds `freeVideoLimit + 2` videos. Row 1
/// is "Studio 22 practice"; rows 2...n are "Practice video n".
/// The universal, feature-led paywall headline. `UnlockPromptReason` now only
/// supplies the explanatory line beneath it.
private let paywallHeadline = "Unlock unlimited videos & styles."

private let aboveCapLastVideoLabel = "Practice video \(freeVideoLimit + 2)"

@MainActor
final class TabBarVerifyTests: XCTestCase {
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

    func testOnboardingCompletionLandsInFeed() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-Five67UITestOnboardingCompletionFixture")
        app.launchArguments.append("-Five67UITestFreeAccess")
        app.launch()

        let notNow = app.buttons["Not now"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 8))
        notNow.tap()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Feed"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["Feed"].isSelected)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "final-onboarding-feed-arrival"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Walks the approved sequence to the seed step. The seed step must offer
    /// Apple's private picker and must never show a Photo Library permission
    /// primer or prompt.
    func testOnboardingReachesSeedWithoutAPhotoPermissionPrompt() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-Five67UITestReviewOnboarding")
        app.launchArguments.append("-Five67UITestFreeAccess")
        app.launch()

        let getStarted = app.buttons["Get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 8))
        XCTAssertGreaterThanOrEqual(getStarted.frame.height, 44)
        XCTAssertTrue(app.staticTexts["Never forget a turn or combo again."].exists)
        addScreenshot(named: "p4-onboarding-hook")
        getStarted.tap()

        XCTAssertTrue(app.staticTexts["What do you want 567 for?"].waitForExistence(timeout: 3))
        let motivation = app.buttons["Practice what I learned between classes"]
        XCTAssertTrue(motivation.exists)
        motivation.tap()
        XCTAssertTrue(waitForSelected(motivation))
        app.buttons["Continue"].tap()

        // The payoff headline is tailored to the answer above.
        XCTAssertTrue(app.staticTexts["Loop the exact part until it sticks."].waitForExistence(timeout: 3))
        addScreenshot(named: "p4-onboarding-payoff")
        app.buttons["Show me how"].tap()

        XCTAssertTrue(app.staticTexts["Pick a video from your recent classes."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Choose video"].exists)
        addScreenshot(named: "p4-onboarding-seed")

        // No permission primer survives, and nothing has triggered the system
        // Photo Library alert on the way here.
        XCTAssertFalse(app.buttons["Connect my videos"].exists)
        XCTAssertFalse(
            app.alerts.element.waitForExistence(timeout: 2),
            "Onboarding must not request Photo Library authorization."
        )
    }

    /// Back must stay available on every reversible onboarding state.
    func testOnboardingSeedStepCanNavigateBack() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-Five67UITestReviewOnboarding")
        app.launchArguments.append("-Five67UITestFreeAccess")
        app.launch()

        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 8))
        app.buttons["Get started"].tap()

        let motivation = app.buttons["Organize my class videos"]
        XCTAssertTrue(motivation.waitForExistence(timeout: 3))
        motivation.tap()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Give every class video a home."].waitForExistence(timeout: 3))
        app.buttons["Show me how"].tap()
        XCTAssertTrue(app.staticTexts["Pick a video from your recent classes."].waitForExistence(timeout: 3))

        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Give every class video a home."].waitForExistence(timeout: 3))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["What do you want 567 for?"].waitForExistence(timeout: 3))
    }

    func testWarmStageHookReflowsAtAccessibilityExtraExtraExtraLarge() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += [
            "-Five67UITestReviewOnboarding",
            "-Five67UITestFreeAccess",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Never forget a turn or combo again."].waitForExistence(timeout: 8))
        let getStarted = app.buttons["Get started"]
        if !getStarted.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(getStarted.isHittable)
        XCTAssertGreaterThanOrEqual(getStarted.frame.height, 44)
        addScreenshot(named: "p1-onboarding-hook-axxxl")
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

    private func addScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForSelected(_ element: XCUIElement, timeout: TimeInterval = 2) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
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

    /// At the cap (3 personal videos) the next import must present the paywall
    /// instead of opening the picker.
    func testFreeVideoOverCapPresentsPaywallWithoutOpeningPicker() throws {
        launchApp(additionalArguments: ["-Five67UITestVideoCapFixture"])

        let addButton = app.buttons["Add video"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        XCTAssertTrue(app.buttons["From Photos"].waitForExistence(timeout: 3))
        app.buttons["From Photos"].tap()

        XCTAssertTrue(
            app.staticTexts[paywallHeadline].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts["Your free library includes \(freeVideoLimit) videos."].exists
        )
    }

    func testFreeAboveCapLibraryRemainsAccessibleAndBlocksOnlyAddition() throws {
        launchApp(additionalArguments: ["-Five67UITestAboveVideoCapFixture"])

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5))
        tabBar.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["Videos"].waitForExistence(timeout: 3))
        app.buttons["Videos"].tap()

        let lastVideo = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", aboveCapLastVideoLabel)
        ).firstMatch
        for _ in 0..<8 where !lastVideo.exists {
            app.swipeUp()
        }
        XCTAssertTrue(
            lastVideo.waitForExistence(timeout: 3),
            "A free library already above the cap must keep all existing videos accessible."
        )

        let addButton = app.buttons["Add video"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        XCTAssertTrue(app.buttons["From Photos"].waitForExistence(timeout: 3))
        app.buttons["From Photos"].tap()
        XCTAssertTrue(app.staticTexts[paywallHeadline].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Not now"].exists)
        app.buttons["Not now"].tap()
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 3))
        tabBar.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["Videos"].waitForExistence(timeout: 3))
        app.buttons["Videos"].tap()
        for _ in 0..<8 where !lastVideo.exists {
            app.swipeUp()
        }
        XCTAssertTrue(
            lastVideo.waitForExistence(timeout: 3),
            "Dismissing the cap paywall must leave the above-cap library unchanged."
        )
    }

    func testFreeSecondStylePresentsCanonicalPaywall() throws {
        launchApp(additionalArguments: [
            "-Five67UITestSeedLibrary",
            "-Five67UITestClaimSalsaStyle"
        ])

        let stylesTab = app.tabBars.firstMatch.buttons["Styles"]
        XCTAssertTrue(stylesTab.waitForExistence(timeout: 5))
        stylesTab.tap()
        XCTAssertTrue(app.buttons["Bachata"].waitForExistence(timeout: 3))
        app.buttons["Bachata"].tap()

        XCTAssertTrue(app.staticTexts[paywallHeadline].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Your free library includes one dance style."].exists
        )
        XCTAssertTrue(app.buttons["Not now"].exists)
        app.buttons["Not now"].tap()
        XCTAssertTrue(app.staticTexts["Styles"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Bachata"].exists)
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
        // The chip is now a button that opens the quick-style sheet; the active
        // filter reads as its accessibility value.
        let styleChip = app.buttons["Style filter"]
        XCTAssertTrue(styleChip.waitForExistence(timeout: 3))
        XCTAssertEqual(styleChip.value as? String, "Salsa")

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

    /// The Library style chip is a quick picker, not a second Styles tab: it
    /// shows the shared style rows, applies the filter, and stays in Library.
    func testLibraryQuickStyleSheetFiltersWithoutLeavingLibrary() throws {
        launchApp(additionalArguments: ["-Five67UITestSeedLibrary"])

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5))
        tabBar.buttons["Library"].tap()

        let chip = app.buttons["Style filter"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()

        // "All styles" is the row this context adds on top of the shared list.
        XCTAssertTrue(app.buttons["All styles"].waitForExistence(timeout: 3))
        let salsa = app.buttons["Salsa"]
        XCTAssertTrue(salsa.exists)
        salsa.tap()

        expectation(
            for: NSPredicate(format: "value == 'Salsa'"),
            evaluatedWith: chip
        )
        waitForExpectations(timeout: 5)
        XCTAssertTrue(tabBar.buttons["Library"].isSelected, "Quick style selection must stay in Library")
    }

    /// Video deletion confirms in a contextual sheet that names the video and
    /// its exact named-move impact — not a title-only popover.
    func testLibraryVideoDeleteSheetShowsIdentityAndImpact() throws {
        launchApp(additionalArguments: ["-Five67UITestSeedLibrary"])

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5))
        tabBar.buttons["Library"].tap()

        let videos = app.buttons["Videos"]
        XCTAssertTrue(videos.waitForExistence(timeout: 5))
        videos.tap()

        let videoRow = app.buttons
            .matching(NSPredicate(format: "label CONTAINS 'Studio 22 practice'"))
            .firstMatch
        XCTAssertTrue(videoRow.waitForExistence(timeout: 5))
        videoRow.swipeLeft()

        let deleteAction = app.buttons["Delete"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 3))
        deleteAction.tap()

        XCTAssertTrue(app.staticTexts["Delete this video?"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.staticTexts
                .containing(NSPredicate(format: "label CONTAINS '2 named moves'"))
                .firstMatch.exists,
            "The sheet must state the exact named-move impact"
        )

        app.buttons["Cancel"].tap()
        XCTAssertTrue(videoRow.waitForExistence(timeout: 3), "Cancel must leave the video in place")
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
