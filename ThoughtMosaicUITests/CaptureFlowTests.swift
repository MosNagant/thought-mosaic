import XCTest

final class CaptureFlowTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data"]
        app.launch()
        XCTAssertTrue(app.textViews["thoughtText"].waitForExistence(timeout: 10))
    }

    func testEmptySaveAndCaptureWithNewTag() {
        XCTAssertFalse(app.buttons["saveNote"].isEnabled)
        let editor = app.textViews["thoughtText"]
        editor.tap()
        editor.typeText("A quiet corner, a new idea.")
        app.buttons["addTags"].tap()
        let search = app.textFields["tagSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap(); search.typeText("Inspiration")
        app.buttons["createTag"].tap()
        app.buttons["confirmTags"].tap()
        app.buttons["saveNote"].tap()
        XCTAssertTrue(app.staticTexts["savedTitle"].waitForExistence(timeout: 3))
        screenshot("saved")
        app.buttons["finishCapture"].tap()
        XCTAssertTrue(app.staticTexts["A quiet corner, a new idea."].waitForExistence(timeout: 3))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["exitEditor"].waitForExistence(timeout: 5))
        app.buttons["exitEditor"].tap()
        XCTAssertTrue(app.staticTexts["A quiet corner, a new idea."].waitForExistence(timeout: 3))
    }

    func testDraftAndDiscard() {
        let editor = app.textViews["thoughtText"]
        editor.tap(); editor.typeText("Keep this draft")
        app.buttons["exitEditor"].tap()
        XCTAssertTrue(app.buttons["keepDraft"].waitForExistence(timeout: 3))
        screenshot("exit-confirmation")
        app.buttons["keepDraft"].tap()
        app.buttons["resumeDraft"].tap()
        XCTAssertEqual(app.textViews["thoughtText"].value as? String, "Keep this draft")
        app.buttons["exitEditor"].tap()
        app.buttons["放弃记录"].tap()
        XCTAssertFalse(app.buttons["resumeDraft"].exists)
    }

    func testFigmaSampleAndTagSheet() {
        screenshot("empty-capture")
        app.buttons["exitEditor"].tap()
        app.swipeUp()
        app.buttons["sampleFlow"].tap()
        XCTAssertTrue(app.textViews["thoughtText"].waitForExistence(timeout: 3))
        screenshot("figma-sample")
        app.buttons["addTags"].tap()
        XCTAssertTrue(app.textFields["tagSearch"].waitForExistence(timeout: 3))
        screenshot("tag-sheet")
        app.buttons["confirmTags"].tap()
        app.buttons["saveNote"].tap()
        XCTAssertTrue(app.staticTexts["savedTitle"].waitForExistence(timeout: 3))
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
