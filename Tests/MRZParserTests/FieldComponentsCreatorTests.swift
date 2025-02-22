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
        case correct(String, OCRCorrector.CorrectionType)
        case isValueValid(_ rawValue: String, _ checkDigit: Int)
        case findMatchingStrings(_ strings: [String]?, _ isCorrectCombination: Bool)
    }

    func testGetRawValueAndCheckDigit() throws {
        let events = LockIsolated([Event]())

        try withDependencies {
            $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                return true
            }
        } operation: {
            let result = try XCTUnwrap(FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                lines: ["", "8501017"],
                format: .td1,
                fieldType: .date(.birth),
                rawValueOCRCorrectionType: .digits,
                isOCRCorrectionEnabled: false
            ))

            XCTAssertEqual(result.0, "850101")
            XCTAssertEqual(result.1, 7)

            expectNoDifference(
                events.value,
                [
                    .isValueValid(
                        "850101",
                        7
                    )
                ]
            )
        }
    }

    func testGetRawValueAndCheckDigitValueNotValid() throws {
        let events = LockIsolated([Event]())

        try withDependencies {
            $0.ocrCorrector.correct = { @Sendable string, correctionType in
                events.withValue { $0.append(.correct(string, correctionType)) }
                return "0"
            }
            $0.ocrCorrector.findMatchingStrings = { @Sendable strings, isCorrectCombination in
                events.withValue { $0.append(.findMatchingStrings(strings, isCorrectCombination(["test", "test", "test"]))) }
                return ["test", "test", "test"]
            }

            $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                return false
            }
        } operation: {
            let result = try XCTUnwrap(FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                lines: ["", "0123456789012345678901234567890123456789012"],
                format: .td3(isVisaDocument: false),
                fieldType: .optionalData(.one),
                rawValueOCRCorrectionType: .digits,
                isOCRCorrectionEnabled: true
            ))

            XCTAssertEqual(result.0, "test")
            XCTAssertEqual(result.1, 0)

            expectNoDifference(
                events.value,
                [
                    .correct(
                        "89012345678901",
                        .digits
                    ),
                    .correct(
                        "2",
                        .digits
                    ),
                    .isValueValid(
                        "0",
                        0
                    ),
                    .findMatchingStrings(
                        ["0"],
                        false
                    )
                ]
            )
        }
    }

    func testCreateStringFieldValueNotValidEmptyCombination() throws {
            let events = LockIsolated([Event]())

            try withDependencies {
                $0.ocrCorrector.correct = { @Sendable string, correctionType in
                    events.withValue { $0.append(.correct(string, correctionType)) }
                    return "0"
                }
                $0.ocrCorrector.findMatchingStrings = { @Sendable strings, isCorrectCombination in
                    events.withValue { $0.append(.findMatchingStrings(strings, isCorrectCombination([]))) }
                    return ["test"]
                }

                $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                    events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                    return false
                }
            } operation: {
                let result = try XCTUnwrap(FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                    lines: ["", "0123456789"],
                    format: .td2(isVisaDocument: true),
                    fieldType: .documentNumber,
                    rawValueOCRCorrectionType: .digits,
                    isOCRCorrectionEnabled: true
                ))

                XCTAssertEqual(result.0, "test")
                XCTAssertEqual(result.1, 0)

                expectNoDifference(
                    events.value,
                    [
                        .correct(
                             "012345678",
                             .digits
                        ),
                        .correct(
                            "9",
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

        func testCreateStringFieldValueNotValidOCRCorrectionDisabled() {
            let events = LockIsolated([Event]())

            withDependencies {
                $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                    events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                    return false
                }
            } operation: {
                XCTAssertNil(
                    FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                        lines: ["", "0123456789"],
                        format: .td2(isVisaDocument: true),
                        fieldType: .documentNumber,
                        rawValueOCRCorrectionType: nil,
                        isOCRCorrectionEnabled: false
                    )
                )

                expectNoDifference(
                    events.value,
                    [
                        .isValueValid(
                            "012345678",
                            9
                        )
                    ]
                )
            }
        }

        func testCreateStringFieldValueNotValidNoMatchingStrings() {
            let events = LockIsolated([Event]())

            withDependencies {
                $0.ocrCorrector.correct = { @Sendable string, correctionType in
                    events.withValue { $0.append(.correct(string, correctionType)) }
                    return "0"
                }
                $0.ocrCorrector.findMatchingStrings = { @Sendable strings, isCorrectCombination in
                    events.withValue { $0.append(.findMatchingStrings(strings, isCorrectCombination(["test", "test", "test"]))) }
                    return nil
                }

                $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                    events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                    return false
                }
            } operation: {
                XCTAssertNil(
                    FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                        lines: ["", "0123456789"],
                        format: .td2(isVisaDocument: true),
                        fieldType: .documentNumber,
                        rawValueOCRCorrectionType: nil,
                        isOCRCorrectionEnabled: true
                    )
                )

                expectNoDifference(
                    events.value,
                    [
                        .correct(
                            "9",
                            .digits
                        ),
                        .isValueValid(
                            "012345678",
                            0
                        ),
                        .findMatchingStrings(
                            [
                                "012345678"
                            ],
                            false
                        )
                    ]
                )
            }
        }

    func testGetRawValueAndCheckDigitNoPosition() {
        XCTAssertNil(
            FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                lines: [],
                format: .td2(isVisaDocument: false),
                fieldType: .optionalData(.two),
                rawValueOCRCorrectionType: nil,
                isOCRCorrectionEnabled: false
            )
        )
    }

    func testGetRawValueAndCheckDigitNoRawValue() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.ocrCorrector.correct = { @Sendable string, correctionType in
                events.withValue { $0.append(.correct(string, correctionType)) }
                return "123"
            }
        } operation: {
            XCTAssertNil(
                FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                    lines: ["", "", "01234567890123456789012345678"],
                    format: .td1,
                    fieldType: .names,
                    rawValueOCRCorrectionType: .letters,
                    isOCRCorrectionEnabled: true
                )
            )

            expectNoDifference(
                events.value,
                [
                    .correct(
                        "01234567890123456789012345678",
                        .letters
                    )
                ]
            )
        }
    }

    func testGetRawValueAndCheckDigitNoCheckDigit() {
        XCTAssertNil(
            FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
                lines: ["ABCDEFGHIJKLMOP"],
                format: .td1,
                fieldType: .documentNumber,
                rawValueOCRCorrectionType: .digits,
                isOCRCorrectionEnabled: false
            )
        )
    }

    func testGetRawValueAndCheckDigitShouldNotValidate() throws {
        let result = try XCTUnwrap(FieldComponentsCreator.liveValue.getRawValueAndCheckDigit(
            lines: ["", "012345678901234567"],
            format: .td1,
            fieldType: .nationality,
            rawValueOCRCorrectionType: .digits,
            isOCRCorrectionEnabled: false
        ))

        XCTAssertEqual(result.0, "567")
        XCTAssertNil(result.1)
    }
}
