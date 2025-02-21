//
//  String+ExtensionsTests.swift
//  MRZParser
//
//  Created by Roman Mazeev on 17/02/2025.
//

import XCTest
@testable import MRZParser

final class String_ExtensionsTests: XCTestCase {
    func testFieldValue() {
        XCTAssertEqual("<ABC<DEF<".fieldValue, "ABC DEF")
        XCTAssertNil("<<<".fieldValue)
        XCTAssertEqual("ABC".fieldValue, "ABC")
    }

    func testTrimmingFilters() {
        XCTAssertEqual("<ABC<DEF<".trimmingFillers, "ABC<DEF")
        XCTAssertEqual("<<<".trimmingFillers, "")
        XCTAssertEqual("ABC".trimmingFillers, "ABC")
    }

    func testReplace() {
        XCTAssertEqual("hello world".replace("world", with: "Swift"), "hello Swift")
        XCTAssertEqual("abc abc abc".replace("abc", with: "123"), "123 123 123")
        XCTAssertEqual("no match here".replace("xyz", with: "test"), "no match here")
    }

    func testSubstring() {
        XCTAssertEqual("hello world".substring(0, to: 4), "hello")
        XCTAssertEqual("abcdef".substring(2, to: 4), "cde")
    }
}
