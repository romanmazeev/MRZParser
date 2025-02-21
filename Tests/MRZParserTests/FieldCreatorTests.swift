//
//  FieldCreatorTests.swift
//  MRZParser
//
//  Created by Roman Mazeev on 17/02/2025.
//

import CustomDump
import Dependencies
import XCTest
@testable import MRZParser

final class FieldCreatorTests: XCTestCase {
    private enum Event: Equatable, Sendable {
        case correct(String, OCRCorrector.CorrectionType)
        case isValueValid(_ rawValue: String, _ checkDigit: Int)
        case findMatchingStrings(_ strings: [String]?, _ isCorrectCombination: Bool)
    }

    // MARK: - String

    func testCreateStringField() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.ocrCorrector.correct = { @Sendable string, correctionType in
                events.withValue { $0.append(.correct(string, correctionType)) }
                return "test"
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createStringField(
                    lines: ["", "012345678901234567890"],
                    format: .td2(isVisaDocument: false),
                    type: .sex,
                    isOCRCorrectionEnabled: true
                ),
                .init(
                    value: "test",
                    rawValue: "test",
                    checkDigit: nil,
                    type: .sex
                )
            )

            expectNoDifference(
                events.value,
                [
                    .correct(
                        "0",
                        .sex
                    )
                ]
            )
        }
    }

    func testCreateStringFieldValueNotValid() {
        let events = LockIsolated([Event]())

        withDependencies {
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
            XCTAssertEqual(
                FieldCreator.liveValue.createStringField(
                    lines: ["", "0123456789012345678901234567890123456789012"],
                    format: .td3(isVisaDocument: false),
                    type: .optionalData(.one),
                    isOCRCorrectionEnabled: true
                ),
                .init(
                    value: "test",
                    rawValue: "test",
                    checkDigit: 0,
                    type: .optionalData(.one)
                )
            )

            expectNoDifference(
                events.value,
                [
                    .correct(
                        "2",
                        .digits
                    ),
                    .isValueValid(
                        "89012345678901",
                        0
                    ),
                    .findMatchingStrings(
                        [
                            "89012345678901"
                        ],
                        false
                    )
                ]
            )
        }
    }

    func testCreateStringFieldValueNotValidEmptyCombination() {
        let events = LockIsolated([Event]())

        withDependencies {
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
            XCTAssertEqual(
                FieldCreator.liveValue.createStringField(
                    lines: ["", "0123456789"],
                    format: .td2(isVisaDocument: true),
                    type: .documentNumber,
                    isOCRCorrectionEnabled: true
                ),
                .init(
                    value: "test",
                    rawValue: "test",
                    checkDigit: 0,
                    type: .documentNumber
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

    func testCreateStringFieldValueNotValidOCRCorrectionDisabled() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                return false
            }
        } operation: {
            XCTAssertNil(
                FieldCreator.liveValue.createStringField(
                    lines: ["", "0123456789"],
                    format: .td2(isVisaDocument: true),
                    type: .documentNumber,
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
                FieldCreator.liveValue.createStringField(
                    lines: ["", "0123456789"],
                    format: .td2(isVisaDocument: true),
                    type: .documentNumber,
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

    func testCreateStringFieldNoPosition() {
        XCTAssertNil(
            FieldCreator.liveValue.createStringField(
                lines: [],
                format: .td2(isVisaDocument: false),
                type: .optionalData(.two),
                isOCRCorrectionEnabled: false
            )
        )
    }

    // MARK: - Names

    func testCreateNamesField() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.ocrCorrector.correct = { @Sendable string, correctionType in
                events.withValue { $0.append(.correct(string, correctionType)) }
                return "<surnames<<givenNames<"
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createNamesField(
                    lines: ["01234567890123456789012345678901234567890123"],
                    format: .td3(isVisaDocument: true),
                    isOCRCorrectionEnabled: true
                ),
                .init(
                    value: .init(surnames: "surnames", givenNames: "givenNames"),
                    rawValue: "<surnames<<givenNames<",
                    checkDigit: nil,
                    type: .names
                )
            )

            expectNoDifference(
                events.value,
                [
                    .correct(
                        "567890123456789012345678901234567890123",
                        .letters
                    )
                ]
            )
        }
    }

    func testCreateNamesFieldWithoutGivenName() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.ocrCorrector.correct = { @Sendable string, correctionType in
                events.withValue { $0.append(.correct(string, correctionType)) }
                return "surname"
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createNamesField(
                    lines: ["01234567890123456789012345678901234567890123"],
                    format: .td3(isVisaDocument: true),
                    isOCRCorrectionEnabled: true
                ),
                .init(
                    value: .init(surnames: "surname", givenNames: nil),
                    rawValue: "surname",
                    checkDigit: nil,
                    type: .names
                )
            )

            expectNoDifference(
                events.value,
                [
                    .correct(
                        "567890123456789012345678901234567890123",
                        .letters
                    )
                ]
            )
        }
    }

    func testCreateNamesFieldNoRawValue() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.ocrCorrector.correct = { @Sendable string, correctionType in
                events.withValue { $0.append(.correct(string, correctionType)) }
                return "123"
            }
        } operation: {
            XCTAssertNil(
                FieldCreator.liveValue.createNamesField(
                    lines: ["", "", "01234567890123456789012345678"],
                    format: .td1,
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

    // MARK: - Date

    func testCreateBirthDateFieldCurrentCentennial() {
        let events = LockIsolated([Event]())
        let correctRawValue: LockIsolated<Bool> = .init(true)

        withDependencies {
            $0.date.now = Date(timeIntervalSince1970: 475788000)
            $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                return true
            }
            $0.ocrCorrector.correct = { @Sendable string, correctionType in
                events.withValue { $0.append(.correct(string, correctionType)) }
                let oldValue = correctRawValue.value
                correctRawValue.setValue(false)
                return oldValue ? "850101" : "8"
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createDateField(
                    lines: ["", "8501017"],
                    format: .td1,
                    dateFieldType: .birth,
                    isOCRCorrectionEnabled: true
                ),
                .init(
                    value: .init(timeIntervalSince1970: 473385600),
                    rawValue: "850101",
                    checkDigit: 8,
                    type: .date(.birth)
                )
            )

            expectNoDifference(
                events.value,
                [
                    .correct(
                        "850101",
                        .digits
                    ),
                    .correct(
                        "7",
                        .digits
                    ),
                    .isValueValid(
                        "850101",
                        8
                    )
                ]
            )
        }
    }

    func testCreateBirthDateFieldPreviousCentennial() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.date.now = .init(timeIntervalSince1970: 475788000)
            $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                return true
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createDateField(
                    lines: ["", "9001017"],
                    format: .td1,
                    dateFieldType: .birth,
                    isOCRCorrectionEnabled: false
                ),
                .init(
                    value: .init(timeIntervalSince1970: -2524521600),
                    rawValue: "900101",
                    checkDigit: 7,
                    type: .date(.birth)
                )
            )

            expectNoDifference(
                events.value,
                [
                    .isValueValid(
                        "900101",
                        7
                    )
                ]
            )
        }
    }

    func testCreateExpiryDateFieldCurrentCentennial() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                return true
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createDateField(
                    lines: ["", "123456789012015"],
                    format: .td1,
                    dateFieldType: .expiry,
                    isOCRCorrectionEnabled: false
                ),
                .init(
                    value: .init(timeIntervalSince1970: 660009600),
                    rawValue: "901201",
                    checkDigit: 5,
                    type: .date(.expiry)
                )
            )

            expectNoDifference(
                events.value,
                [
                    .isValueValid(
                        "901201",
                        5
                    )
                ]
            )
        }
    }

    func testCreateExpiryDateFieldPreviousCentennial() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.date.now = .init(timeIntervalSince1970: -1577664000)
            $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                return true
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createDateField(
                    lines: ["", "123456789012015"],
                    format: .td1,
                    dateFieldType: .expiry,
                    isOCRCorrectionEnabled: false
                ),
                .init(
                    value: .init(timeIntervalSince1970: -2495664000),
                    rawValue: "901201",
                    checkDigit: 5,
                    type: .date(.expiry)
                )
            )

            expectNoDifference(
                events.value,
                [
                    .isValueValid(
                        "901201",
                        5
                    )
                ]
            )
        }
    }

    func testCreateDateFieldNoParsedYear() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.validator.isValueValid = { @Sendable rawValue, checkDigit in
                events.withValue { $0.append(.isValueValid(rawValue, checkDigit)) }
                return true
            }
        } operation: {
            XCTAssertNil(
                FieldCreator.liveValue.createDateField(
                    lines: ["", "ABCDEFGHIJKLMOPQRST9"],
                    format: .td2(isVisaDocument: true),
                    dateFieldType: .birth,
                    isOCRCorrectionEnabled: false
                )
            )

            expectNoDifference(
                events.value,
                [
                    .isValueValid(
                        "OPQRST",
                        9
                    )
                ]
            )
        }
    }

    func testCreateDateFieldNoCheckDigit() {
        XCTAssertNil(
            FieldCreator.liveValue.createDateField(
                lines: ["", "0123456789012345678A"],
                format: .td3(isVisaDocument: false),
                dateFieldType: .birth,
                isOCRCorrectionEnabled: false
            )
        )
    }

    // MARK: - Int

    func testCreateIntField() {
        XCTAssertEqual(
            FieldCreator.liveValue.createIntField(
                lines: ["", "01234567890123456789012345678901234567890123"],
                format: .td3(isVisaDocument: false),
                isOCRCorrectionEnabled: false
            ),
            .init(
                value: 3,
                rawValue: "3",
                checkDigit: nil,
                type: .finalCheckDigit
            )
        )
    }

    func testCreateIntFieldNotIntValue() {
        XCTAssertNil(
            FieldCreator.liveValue.createIntField(
                lines: ["", "ABCDEFGHIJKLMOPQRSTUVWXYZABCDE"],
                format: .td1,
                isOCRCorrectionEnabled: false
            )
        )
    }
}
