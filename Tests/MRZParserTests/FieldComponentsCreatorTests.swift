//
//  FieldComponentsCreatorTests.swift
//  MRZParser
//
//  Created by Roman Mazeev on 22/02/2025.
//

import CustomDump
import Dependencies
import XCTest
@testable import MRZParser

final class FieldComponentsCreatorTests: XCTestCase {
    private enum Event: Equatable, Sendable {
        case correct(String, FieldType.ContentType)
        case isValueValid(_ rawValue: String, _ checkDigit: Int)
        case isContentTypeValid(_ value: String, _ contentType: FieldType.ContentType)
        case findMatchingStrings(_ strings: [String]?, _ isCorrectCombination: Bool)
    }

    func testGetRawValueAndCheckDigitShouldNotValidateCheckDigit() throws {
        let events = LockIsolated([Event]())

        try withDependencies {
            $0.validator.isContentTypeValid = { @Sendable value, contentType in
                events.withValue { $0.append(.isContentTypeValid(value, contentType)) }
                return true
            }
        } operation: {
            let result = try XCTUnwrap(FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                lines: ["850101"],
                position: .init(line: 0, range: 0..<5),
                contentType: .digits,
                shouldValidateCheckDigit: false,
                isOCRCorrectionEnabled: false
            ))

            XCTAssertEqual(result.0, "85010")
            XCTAssertNil(result.1)

            expectNoDifference(
                events.value,
                [
                    .isContentTypeValid(
                        "85010",
                        .digits
                    )
                ]
            )
        }
    }

    func testGetRawValueAndCheckRawValueNotValid() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.validator.isContentTypeValid = { @Sendable value, contentType in
                events.withValue { $0.append(.isContentTypeValid(value, contentType)) }
                return false
            }
        } operation: {
            XCTAssertNil(FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                lines: ["850101"],
                position: .init(line: 0, range: 0..<5),
                contentType: .digits,
                shouldValidateCheckDigit: true,
                isOCRCorrectionEnabled: false
            ))

            expectNoDifference(
                events.value,
                [
                    .isContentTypeValid(
                        "85010",
                        .digits
                    )
                ]
            )
        }
    }

    func testGetRawValueAndCheckDigitNoCheckDigit() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.validator.isContentTypeValid = { @Sendable value, contentType in
                events.withValue { $0.append(.isContentTypeValid(value, contentType)) }
                return true
            }
            $0.ocrCorrector.correct = { @Sendable string, correctionType in
                events.withValue { $0.append(.correct(string, correctionType)) }
                return "A"
            }
        } operation: {
            XCTAssertNil(FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                lines: ["850101"],
                position: .init(line: 0, range: 0..<5),
                contentType: .digits,
                shouldValidateCheckDigit: true,
                isOCRCorrectionEnabled: true
            ))

            expectNoDifference(
                events.value,
                [
                    .correct(
                        "85010",
                        .digits
                    ),
                    .isContentTypeValid(
                        "A",
                        .digits
                    ),
                    .correct(
                        "1",
                        .digits
                    )
                ]
            )
        }
    }

    func testGetRawValueAndCheckDigit() throws {
        let events = LockIsolated([Event]())

        try withDependencies {
            $0.validator.isContentTypeValid = { @Sendable value, contentType in
                events.withValue { $0.append(.isContentTypeValid(value, contentType)) }
                return true
            }
            $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                return true
            }
        } operation: {
            let result = try XCTUnwrap(FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                lines: ["850101"],
                position: .init(line: 0, range: 0..<5),
                contentType: .digits,
                shouldValidateCheckDigit: true,
                isOCRCorrectionEnabled: false
            ))

            XCTAssertEqual(result.0, "85010")
            XCTAssertEqual(result.1, 1)

            expectNoDifference(
                events.value,
                [
                    .isContentTypeValid(
                        "85010",
                        .digits
                    ),
                    .isValueValid(
                        "85010",
                        1
                    )
                ]
            )
        }
    }

    func testGetRawValueAndCheckDigitValueNotValid() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.validator.isContentTypeValid = { @Sendable value, contentType in
                events.withValue { $0.append(.isContentTypeValid(value, contentType)) }
                return true
            }
            $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                return false
            }
        } operation: {
            XCTAssertNil(FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                lines: ["850101"],
                position: .init(line: 0, range: 0..<5),
                contentType: .digits,
                shouldValidateCheckDigit: true,
                isOCRCorrectionEnabled: false
            ))

            expectNoDifference(
                events.value,
                [
                    .isContentTypeValid(
                        "85010",
                        .digits
                    ),
                    .isValueValid(
                        "85010",
                        1
                    )
                ]
            )
        }
    }

    func testGetRawValueAndCheckDigitValueNotValidMatchingString() throws {
        let events = LockIsolated([Event]())

        try withDependencies {
            $0.validator.isContentTypeValid = { @Sendable value, contentType in
                events.withValue { $0.append(.isContentTypeValid(value, contentType)) }
                return true
            }
            $0.ocrCorrector.correct = { @Sendable string, correctionType in
                events.withValue { $0.append(.correct(string, correctionType)) }
                return "0"
            }
            $0.ocrCorrector.findMatchingStrings = { @Sendable strings, isCorrectCombination in
                events.withValue { $0.append(.findMatchingStrings(strings, isCorrectCombination(["test", "test"]))) }
                return ["test"]
            }

            $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                return false
            }
        } operation: {
            let result = try XCTUnwrap(FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                lines: ["850101"],
                position: .init(line: 0, range: 0..<5),
                contentType: .mixed,
                shouldValidateCheckDigit: true,
                isOCRCorrectionEnabled: true
            ))

            XCTAssertEqual(result.0, "test")
            XCTAssertEqual(result.1, 0)

            expectNoDifference(
                events.value,
                [
                    .correct(
                        "85010",
                        .mixed
                    ),
                    .isContentTypeValid(
                        "0",
                        .mixed
                    ),
                    .correct(
                        "1",
                        .digits
                    ),
                    .isValueValid(
                        "0",
                        0
                    ),
                    .findMatchingStrings(
                        [
                            "0"
                        ],
                        false
                    )
                ]
            )
        }
    }

    func testGetRawValueAndCheckDigitValueNotValidMatchingStringsEmptyCombination() throws {
        let events = LockIsolated([Event]())

        try withDependencies {
            $0.validator.isContentTypeValid = { @Sendable value, contentType in
                events.withValue { $0.append(.isContentTypeValid(value, contentType)) }
                return true
            }
            $0.ocrCorrector.correct = { @Sendable string, correctionType in
                events.withValue { $0.append(.correct(string, correctionType)) }
                return "0"
            }
            $0.ocrCorrector.findMatchingStrings = { @Sendable strings, isCorrectCombination in
                events.withValue { $0.append(.findMatchingStrings(strings, isCorrectCombination([]))) }
                return ["test", "test"]
            }

            $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                return false
            }
        } operation: {
            let result = try XCTUnwrap(FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                lines: ["8a5c010"],
                position: .init(line: 0, range: 0..<5),
                contentType: .mixed,
                shouldValidateCheckDigit: true,
                isOCRCorrectionEnabled: true
            ))

            XCTAssertEqual(result.0, "test")
            XCTAssertEqual(result.1, 0)

            expectNoDifference(
                events.value,
                [
                    .correct(
                        "8A5C0",
                        .mixed
                    ),
                    .isContentTypeValid(
                        "0",
                        .mixed
                    ),
                    .correct(
                        "1",
                        .digits
                    ),
                    .isValueValid(
                        "0",
                        0
                    ),
                    .findMatchingStrings(
                        [
                            "0"
                        ],
                        false
                    )
                ]
            )
        }
    }

    func testGetRawValueAndCheckDigitValueNotValidNoMatchingStrings() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.validator.isContentTypeValid = { @Sendable value, contentType in
                events.withValue { $0.append(.isContentTypeValid(value, contentType)) }
                return true
            }
            $0.ocrCorrector.correct = { @Sendable string, correctionType in
                events.withValue { $0.append(.correct(string, correctionType)) }
                return "0"
            }
            $0.ocrCorrector.findMatchingStrings = { @Sendable strings, isCorrectCombination in
                events.withValue { $0.append(.findMatchingStrings(strings, isCorrectCombination([]))) }
                return []
            }

            $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                return false
            }
        } operation: {
            XCTAssertNil(FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                lines: ["8A!a0O"],
                position: .init(line: 0, range: 0..<5),
                contentType: .mixed,
                shouldValidateCheckDigit: true,
                isOCRCorrectionEnabled: true
            ))

            expectNoDifference(
                events.value,
                [
                    .correct(
                        "8A!A0",
                        .mixed
                    ),
                    .isContentTypeValid(
                        "0",
                        .mixed
                    ),
                    .correct(
                        "O",
                        .digits
                    ),
                    .isValueValid(
                        "0",
                        0
                    ),
                    .findMatchingStrings(
                        [
                            "0"
                        ],
                        false
                    )
                ]
            )
        }
    }
}
