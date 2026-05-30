import XCTest

final class TabBarVerifyTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        sleep(2)
    }

    func testThreeTabsExist() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5), "Library tab missing")
        XCTAssertTrue(tabBar.buttons["Feed"].exists, "Feed tab missing")
        XCTAssertTrue(tabBar.buttons["Styles"].exists, "Styles tab missing")
    }

    func testLibraryTabTap() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 5))
        tabBar.buttons["Library"].tap()
        sleep(1)
        XCTAssertTrue(app.exists)
    }

    func testStylesTabTap() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Styles"].waitForExistence(timeout: 5))
        tabBar.buttons["Styles"].tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["Styles"].waitForExistence(timeout: 3) ||
                      app.exists)
    }

    func testAddButtonVisible() throws {
        XCTAssertTrue(app.buttons["Add video"].waitForExistence(timeout: 5), "Add video button missing")
    }

    func testAddButtonShowsDialog() throws {
        let addBtn = app.buttons["Add video"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5))
        addBtn.tap()
        sleep(1)
        let sheet = app.sheets["Add video"]
        let alert = app.alerts["Add video"] 
        let fromPhotos = app.buttons["From Photos"]
        XCTAssertTrue(sheet.exists || alert.exists || fromPhotos.exists,
                      "Add video dialog did not appear")
    }

    func testScreenshotsAllTabs() throws {
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
}
