//
//  OCRCorrectorTests.swift
//  MRZParser
//
//  Created by Roman Mazeev on 17/02/2025.
//

import ConcurrencyExtras
import XCTest
@testable import MRZParser

final class OCRCorrectorTests: XCTestCase {
    // MARK: - correct

    func testCorrectDigits() {
        XCTAssertEqual(OCRCorrector.liveValue.correct(string: "OQUDIZBK", contentType: .digits), "0000128K")
    }

    func testCorrectLetters() {
        XCTAssertEqual(OCRCorrector.liveValue.correct(string: "01284", contentType: .letters), "OIZB4")
    }

    func testCorrectSex() {
        XCTAssertEqual(OCRCorrector.liveValue.correct(string: "PZ", contentType: .sex), "FZ")
    }

    func testCorrectMixed() {
        XCTAssertEqual(OCRCorrector.liveValue.correct(string: "OQUDIZBK", contentType: .mixed), "OQUDIZBK")
    }

    // MARK: - findMatchingStrings

    func testFindMatchingStringsSecondCheckValid() {
        let isCorrect = LockIsolated(false)

        let result = OCRCorrector.liveValue.findMatchingStrings(strings: ["012UD", "ZBK84"]) { @Sendable _ in
            let correct = isCorrect.value
            isCorrect.setValue(true)
            return correct
        }

        XCTAssertEqual(result, ["012UD", "2BK84"])
    }

    func testFindMatchingStringsNoMatchingStrings() {
        XCTAssertNil(OCRCorrector.liveValue.findMatchingStrings(strings: ["012UD", "ZBK84"]) { _ in false })
    }
}
