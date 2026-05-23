import XCTest
@testable import Soulseeker

final class KeychainHelperTests: XCTestCase {
    let testKey = "soulseeker.test.key"

    override func tearDown() {
        KeychainHelper.delete(for: testKey)
    }

    func testSaveAndLoad() throws {
        try KeychainHelper.save("hello", for: testKey)
        XCTAssertEqual(KeychainHelper.load(for: testKey), "hello")
    }

    func testOverwrite() throws {
        try KeychainHelper.save("first", for: testKey)
        try KeychainHelper.save("second", for: testKey)
        XCTAssertEqual(KeychainHelper.load(for: testKey), "second")
    }

    func testLoadMissingReturnsNil() {
        XCTAssertNil(KeychainHelper.load(for: "soulseeker.definitely.not.here.xyz"))
    }

    func testDelete() throws {
        try KeychainHelper.save("value", for: testKey)
        KeychainHelper.delete(for: testKey)
        XCTAssertNil(KeychainHelper.load(for: testKey))
    }
}
