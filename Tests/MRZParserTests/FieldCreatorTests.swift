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
        case getRawValueAndCheckDigit(
            _ lines: [String],
            _ position: FieldType.FieldPosition,
            _ contentType: FieldType.ContentType,
            _ shouldValidateCheckDigit: Bool,
            _ isOCRCorrectionEnabled: Bool
        )
        case convert(String)
        case isContentTypeValid(_ value: String, _ contentType: FieldType.ContentType)
    }

    // MARK: - String

    func testCreateStringField() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("test", 9)
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createStringField(
                    lines: [],
                    format: .td2(isVisaDocument: false),
                    type: .sex,
                    isRussianNationalPassport: true,
                    isOCRCorrectionEnabled: false
                ),
                .init(
                    value: "test",
                    rawValue: "test",
                    checkDigit: 9,
                    type: .sex
                )
            )

            expectNoDifference(
                events.value,
                [
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 1,
                            range: 20..<21
                        ),
                        .sex,
                        false,
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
                format: .td2(isVisaDocument: true),
                type: .optionalData(.two),
                isRussianNationalPassport: false,
                isOCRCorrectionEnabled: true
            )
        )
    }

    func testCreateStringFieldNoValue() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("", 9)
            }
        } operation: {
            XCTAssertNil(
                FieldCreator.liveValue.createStringField(
                    lines: [],
                    format: .td3(isVisaDocument: false),
                    type: .optionalData(.one),
                    isRussianNationalPassport: true,
                    isOCRCorrectionEnabled: true
                )
            )

            expectNoDifference(
                events.value,
                [
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 1,
                            range: 28..<42
                        ),
                        .digits,
                        true,
                        true
                    )
                ]
            )
        }
    }

    // MARK: - DocumentNumber

    func testCreateDocumentNumberField() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("1234567890", 4)
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createDocumentNumberField(
                    lines: [],
                    format: .td1,
                    russianNationalPassportHiddenCharacter: "S",
                    isOCRCorrectionEnabled: false
                ),
                .init(
                    value: "123S4567890",
                    rawValue: "1234567890",
                    checkDigit: 4,
                    type: .documentNumber
                )
            )

            expectNoDifference(
                events.value,
                [
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 0,
                            range: 5..<14
                        ),
                        .digits,
                        true,
                        false
                    )
                ]
            )
        }
    }

    func testCreateDocumentNumberFieldNoValue() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("", 4)
            }
        } operation: {
            XCTAssertNil(
                FieldCreator.liveValue.createDocumentNumberField(
                    lines: [],
                    format: .td3(isVisaDocument: false),
                    russianNationalPassportHiddenCharacter: nil,
                    isOCRCorrectionEnabled: false
                )
            )

            expectNoDifference(
                events.value,
                [
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 1,
                            range: 0..<9
                        ),
                        .mixed,
                        true,
                        false
                    )
                ]
            )
        }
    }


    // MARK: - Character

    func testCreateCharacterField() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("K", nil)
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createCharacterField(
                    lines: [],
                    format: .td2(isVisaDocument: true),
                    type: .documentTypeAdditional,
                    isOCRCorrectionEnabled: false
                ),
                .init(
                    value: "K",
                    rawValue: "K",
                    checkDigit: nil,
                    type: .documentTypeAdditional
                )
            )

            expectNoDifference(
                events.value,
                [
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 0,
                            range: 1..<2
                        ),
                        .letters,
                        false,
                        false
                    )
                ]
            )
        }
    }

    func testCreateCharacterFieldNoValue() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("", 4)
            }
        } operation: {
            XCTAssertNil(
                FieldCreator.liveValue.createCharacterField(
                    lines: [],
                    format: .td1,
                    type: .sex,
                    isOCRCorrectionEnabled: true
                )
            )

            expectNoDifference(
                events.value,
                [
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 1,
                            range: 7..<8
                        ),
                        .sex,
                        false,
                        true
                    )
                ]
            )
        }
    }

    // MARK: - Names

    func testCreateNamesFieldContentTypeNotValid() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("test", nil)
            }
            $0.cyrillicNameConverter.convert = { @Sendable rawValue in
                events.withValue { $0.append(.convert(rawValue)) }
                return "<surnames<<givenNames<"
            }
            $0.validator.isContentTypeValid = { @Sendable value, contentType in
                events.withValue { $0.append(.isContentTypeValid(value, contentType)) }
                return false
            }
        } operation: {
            XCTAssertNil(
                FieldCreator.liveValue.createNamesField(
                    lines: [],
                    format: .td2(isVisaDocument: true),
                    isRussianNationalPassport: true,
                    isOCRCorrectionEnabled: true
                )
            )

            expectNoDifference(
                events.value,
                [
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 0,
                            range: 5..<36
                        ),
                        .mixed,
                        false,
                        true
                    ),
                    .convert("test"),
                    .isContentTypeValid(
                        "<surnames<<givenNames<",
                        .letters
                    )
                ]
            )
        }
    }

    func testCreateNamesField() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("test", nil)
            }
            $0.cyrillicNameConverter.convert = { @Sendable rawValue in
                events.withValue { $0.append(.convert(rawValue)) }
                return "<surnames<<givenNames<"
            }
            $0.validator.isContentTypeValid = { @Sendable value, contentType in
                events.withValue { $0.append(.isContentTypeValid(value, contentType)) }
                return true
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createNamesField(
                    lines: [],
                    format: .td3(isVisaDocument: true),
                    isRussianNationalPassport: true,
                    isOCRCorrectionEnabled: true
                ),
                .init(
                    value: .init(surnames: "surnames", givenNames: "givenNames"),
                    rawValue: "test",
                    checkDigit: nil,
                    type: .names
                )
            )

            expectNoDifference(
                events.value,
                [
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 0,
                            range: 5..<44
                        ),
                        .mixed,
                        false,
                        true
                    ),
                    .convert("test"),
                    .isContentTypeValid(
                        "<surnames<<givenNames<",
                        .letters
                    )
                ]
            )
        }
    }

    func testCreateNamesFieldWithoutGivenName() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("surname", nil)
            }
            $0.validator.isContentTypeValid = { @Sendable value, contentType in
                events.withValue { $0.append(.isContentTypeValid(value, contentType)) }
                return true
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createNamesField(
                    lines: [],
                    format: .td3(isVisaDocument: false),
                    isRussianNationalPassport: false,
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
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 0,
                            range: 5..<44
                        ),
                        .letters,
                        false,
                        true
                    ),
                    .isContentTypeValid(
                        "surname",
                        .letters
                    )
                ]
            )
        }
    }

    func testCreateNamesFieldNoValue() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return nil
            }
        } operation: {
            XCTAssertNil(
                FieldCreator.liveValue.createNamesField(
                    lines: [],
                    format: .td1,
                    isRussianNationalPassport: false,
                    isOCRCorrectionEnabled: true
                )
            )

            expectNoDifference(
                events.value,
                [
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 2,
                            range: 0..<29
                        ),
                        .letters,
                        false,
                        true
                    )
                ]
            )
        }
    }

    // MARK: - Date

    func testCreateBirthDateFieldCurrentCentennial() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.date.now = Date(timeIntervalSince1970: 475788000)
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("850101", 8)
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createDateField(
                    lines: [],
                    format: .td3(isVisaDocument: true),
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
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 1,
                            range: 13..<19
                        ),
                        .digits,
                        true,
                        true
                    )
                ]
            )
        }
    }

    func testCreateBirthDateFieldPreviousCentennial() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.date.now = .init(timeIntervalSince1970: 475788000)
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("900101", 7)
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createDateField(
                    lines: [],
                    format: .td1,
                    dateFieldType: .birth,
                    isOCRCorrectionEnabled: true
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
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 1,
                            range: 0..<6
                        ),
                        .digits,
                        true,
                        true
                    )
                ]
            )
        }
    }

    func testCreateExpiryDateFieldCurrentCentennial() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("901201", 5)
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createDateField(
                    lines: [],
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
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 1,
                            range: 8..<14
                        ),
                        .digits,
                        true,
                        false
                    )
                ]
            )
        }
    }

    func testCreateExpiryDateFieldPreviousCentennial() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.date.now = .init(timeIntervalSince1970: -1577664000)
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("901201", 5)
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createDateField(
                    lines: [],
                    format: .td2(isVisaDocument: false),
                    dateFieldType: .expiry,
                    isOCRCorrectionEnabled: true
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
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 1,
                            range: 21..<27
                        ),
                        .digits,
                        true,
                        true
                    )
                ]
            )
        }
    }

    func testCreateDateFieldNoParsedYear() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("test", nil)
            }
        } operation: {
            XCTAssertNil(
                FieldCreator.liveValue.createDateField(
                    lines: [],
                    format: .td2(isVisaDocument: true),
                    dateFieldType: .birth,
                    isOCRCorrectionEnabled: false
                )
            )

            expectNoDifference(
                events.value,
                [
                    .getRawValueAndCheckDigit(
                        [],
                        .init(
                            line: 1,
                            range: 13..<19
                        ),
                        .digits,
                        true,
                        false
                    )
                ]
            )
        }
    }

    // MARK: - Int

    func testCreateFinalCheckDigitField() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("9", nil)
            }
        } operation: {
            XCTAssertEqual(
                FieldCreator.liveValue.createFinalCheckDigitField(
                    lines: ["test"],
                    format: .td3(isVisaDocument: false),
                    isOCRCorrectionEnabled: true
                ),
                .init(
                    value: 9,
                    rawValue: "9",
                    checkDigit: nil,
                    type: .finalCheckDigit
                )
            )

            expectNoDifference(
                events.value,
                [
                    .getRawValueAndCheckDigit(
                        [
                            "test"
                        ],
                        .init(
                            line: 1,
                            range: 43..<44
                        ),
                        .digits,
                        false,
                        true
                    )
                ]
            )
        }
    }

    func testCreateFinalCheckDigitNoPosition() {
        XCTAssertNil(
            FieldCreator.liveValue.createFinalCheckDigitField(
                lines: [],
                format: .td2(isVisaDocument: true),
                isOCRCorrectionEnabled: true
            )
        )
    }

    func testCreateFinalCheckDigitFieldNotIntValue() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldComponentsCreator.getRawValueAndCheckDigit = { @Sendable lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.getRawValueAndCheckDigit(lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled)) }
                return ("test", 0)
            }
        } operation: {
            XCTAssertNil(
                FieldCreator.liveValue.createFinalCheckDigitField(
                    lines: ["test", "test"],
                    format: .td1,
                    isOCRCorrectionEnabled: false
                )
            )

            expectNoDifference(
                events.value,
                [
                    .getRawValueAndCheckDigit(
                        [
                            "test",
                            "test"
                        ],
                        .init(
                            line: 1,
                            range: 29..<30
                        ),
                        .digits,
                        false,
                        false
                    )
                ]
            )
        }
    }
}
