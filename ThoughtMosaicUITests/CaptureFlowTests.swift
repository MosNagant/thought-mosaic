import XCTest

final class CaptureFlowTests: XCTestCase {
    private var app: XCUIApplication!
    private var testSession = UUID().uuidString
    private var editor: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "thoughtText").firstMatch
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--test-session=\(testSession)", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
    }

    func testEmptySaveAndCaptureWithNewTag() {
        XCTAssertFalse(app.buttons["saveNote"].isEnabled)
        editor.tap()
        editor.typeText("A quiet corner, a new idea.")
        app.buttons["finishTyping"].tap()
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
        app.launch()
        XCTAssertTrue(app.buttons["exitEditor"].waitForExistence(timeout: 5))
        app.buttons["exitEditor"].tap()
        XCTAssertTrue(app.staticTexts["A quiet corner, a new idea."].waitForExistence(timeout: 3))
    }

    func testDraftAndDiscard() {
        editor.tap(); editor.typeText("Keep this draft")
        app.buttons["exitEditor"].tap()
        XCTAssertTrue(app.buttons["保留草稿"].waitForExistence(timeout: 3))
        screenshot("exit-confirmation")
        app.buttons["保留草稿"].firstMatch.tap()
        XCTAssertTrue(editor.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["resumeDraft"].waitForExistence(timeout: 3))
        screenshot("draft-library")
        app.buttons["resumeDraft"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        XCTAssertEqual(editor.value as? String, "Keep this draft")
        app.buttons["exitEditor"].tap()
        app.buttons["放弃记录"].tap()
        XCTAssertFalse(app.buttons["resumeDraft"].exists)
    }

    func testFigmaSampleAndTagSheet() {
        screenshot("empty-capture")
        app.buttons["exitEditor"].tap()
        app.swipeUp()
        app.buttons["sampleFlow"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        screenshot("figma-sample")
        app.buttons["addTags"].tap()
        XCTAssertTrue(app.textFields["tagSearch"].waitForExistence(timeout: 3))
        screenshot("tag-sheet")
        app.buttons["confirmTags"].tap()
        app.buttons["saveNote"].tap()
        XCTAssertTrue(app.staticTexts["savedTitle"].waitForExistence(timeout: 3))
    }

    func testKeyboardDismissAndCancelExitKeepText() {
        editor.tap()
        editor.typeText("First line\nSecond line\nThird line")
        XCTAssertEqual(editor.value as? String, "First line\nSecond line\nThird line")
        XCTAssertTrue(app.buttons["finishTyping"].isHittable)
        XCTAssertTrue(app.buttons["dismissKeyboard"].isHittable)
        app.buttons["dismissKeyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        editor.tap()
        app.buttons["exitEditor"].tap()
        XCTAssertTrue(app.buttons["继续编辑"].waitForExistence(timeout: 3))
        app.buttons["继续编辑"].tap()
        XCTAssertEqual(editor.value as? String, "First line\nSecond line\nThird line")
        editor.typeText("\nStill here")
        app.buttons["saveNote"].tap()
        XCTAssertTrue(app.staticTexts["savedTitle"].waitForExistence(timeout: 3))
        app.buttons["captureAgain"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["exitEditor"].isHittable)
        XCTAssertFalse(app.buttons["saveNote"].isEnabled)
        app.buttons["exitEditor"].tap()
        XCTAssertTrue(app.buttons["newNote"].waitForExistence(timeout: 3))
    }

    func testClearedDraftDoesNotComeBackOnExit() {
        editor.tap(); editor.typeText("Clear this draft")
        XCTAssertEqual(editor.value as? String, "Clear this draft")
        app.buttons["exitEditor"].tap()
        app.buttons["保留草稿"].firstMatch.tap()
        XCTAssertTrue(editor.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["resumeDraft"].waitForExistence(timeout: 3))
        app.buttons["resumeDraft"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.tap()
        editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Clear this draft".count))
        app.buttons["exitEditor"].tap()
        XCTAssertTrue(app.buttons["放弃记录"].waitForExistence(timeout: 3))
        app.buttons["放弃记录"].tap()
        XCTAssertFalse(app.buttons["resumeDraft"].exists)
    }

    func testCancelTagChangesAndReturnToSavedNote() {
        editor.tap(); editor.typeText("Keep saved text")
        XCTAssertEqual(editor.value as? String, "Keep saved text")
        app.buttons["saveNote"].tap()
        XCTAssertTrue(app.staticTexts["savedTitle"].waitForExistence(timeout: 3))
        app.buttons["finishCapture"].tap()
        app.staticTexts["Keep saved text"].tap()
        app.buttons["addTags"].tap()
        let search = app.textFields["tagSearch"]
        search.tap(); search.typeText("Temporary")
        app.buttons["createTag"].tap()
        XCTAssertTrue(app.buttons["confirmTags"].isHittable)
        app.buttons["取消标签修改"].tap()
        XCTAssertFalse(app.buttons["Temporary"].exists)
        app.buttons["exitEditor"].tap()
        XCTAssertTrue(app.buttons["newNote"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["保留草稿"].exists)
    }

    func testLongTextCanDismissKeyboardAndSave() {
        let text = (1...14).map { "Line \($0): an idea to keep." }.joined(separator: "\n")
        editor.tap(); editor.typeText(text)
        XCTAssertEqual(editor.value as? String, text)
        XCTAssertTrue(app.buttons["dismissKeyboard"].isHittable)
        app.buttons["dismissKeyboard"].tap()
        XCTAssertTrue(app.buttons["saveNote"].isHittable)
        app.buttons["saveNote"].tap()
        XCTAssertTrue(app.staticTexts["savedTitle"].waitForExistence(timeout: 3))
        app.buttons["finishCapture"].tap()
        app.terminate(); app.launch()
        app.buttons["exitEditor"].tap()
        let note = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-' ")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        note.tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        XCTAssertEqual(editor.value as? String, text)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
