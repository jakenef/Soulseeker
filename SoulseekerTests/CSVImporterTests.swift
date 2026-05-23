import XCTest
@testable import Soulseeker

final class CSVImporterTests: XCTestCase {
    func testBasicParse() {
        let result = CSVImporter.parse("Radiohead,Creep\nPink Floyd,Time")
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].artist, "Radiohead")
        XCTAssertEqual(result[0].title, "Creep")
        XCTAssertEqual(result[1].artist, "Pink Floyd")
        XCTAssertEqual(result[1].title, "Time")
    }

    func testHeaderRowSkipped() {
        let result = CSVImporter.parse("artist,title\nRadiohead,Creep")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].artist, "Radiohead")
    }

    func testCaseInsensitiveHeader() {
        let result = CSVImporter.parse("Artist,Title\nRadiohead,Creep")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].artist, "Radiohead")
    }

    func testTitleWithComma() {
        let result = CSVImporter.parse("Radiohead,Karma Police, Part 2")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "Karma Police, Part 2")
    }

    func testEmptyLinesIgnored() {
        let result = CSVImporter.parse("Radiohead,Creep\n\nPink Floyd,Time\n")
        XCTAssertEqual(result.count, 2)
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertEqual(CSVImporter.parse("").count, 0)
    }

    func testRowMissingTitleSkipped() {
        let result = CSVImporter.parse("Radiohead\nPink Floyd,Time")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].artist, "Pink Floyd")
    }
}
