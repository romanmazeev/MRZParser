//
//  MRZCodeCreatorTests.swift
//  MRZParser
//
//  Created by Roman Mazeev on 17/02/2025.
//

import CustomDump
import Dependencies
import XCTest
@testable import MRZParser

final class MRZCodeCreatorTests: XCTestCase {
    private enum Event: Equatable, Sendable {
        case createField(_ lines: [String], _ format: MRZCode.Format, _ type: FieldType, _ isOCRCorrectionEnabled: Bool)
        case validateComposition(_ fields: [Field<String>], checkDigit: Int)
        case findMatchingStrings(_ strings: [String]?, _ isCorrectCombination: Bool)
    }

    func testCreateNoFirstLine() {
        XCTAssertNil(
            MRZCodeCreator.liveValue.create(
                mrzLines: [],
                isOCRCorrectionEnabled: false
            )
        )
    }

    func testCreateInvalidLineCount() {
        let mrzLines = ["test", "test", "test", "test"]

        XCTAssertNil(
            MRZCodeCreator.liveValue.create(
                mrzLines: mrzLines,
                isOCRCorrectionEnabled: false
            )
        )
    }

    func testCreateNotUniformedLineLength() {
        let mrzLines = ["test", "testtest"]

        XCTAssertNil(
            MRZCodeCreator.liveValue.create(
                mrzLines: mrzLines,
                isOCRCorrectionEnabled: false
            )
        )
    }

    func testCreateTD1InvalidLineLength() {
        let mrzLines = ["test", "test", "test"]

        XCTAssertNil(
            MRZCodeCreator.liveValue.create(
                mrzLines: mrzLines,
                isOCRCorrectionEnabled: false
            )
        )
    }

    func testCreateTD1NoRequiredField() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldCreator.createStringField = { @Sendable lines, format, type, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, type, isOCRCorrectionEnabled)) }
                return nil
            }
        } operation: {
            let mrzLines = ["I<UTOD231458907<<<<<<<<<<<<<<<", "7408122X1204159UTO<<<<<<<<<<<6", "ERIKSSON<<ANNA<MARIA<<<<<<<<<<"]
            let isOCRCorrectionEnabled = false

            XCTAssertNil(
                MRZCodeCreator.liveValue.create(
                    mrzLines: mrzLines,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                )
            )

            expectNoDifference(
                events.value,
                [
                    .createField(
                        mrzLines,
                        .td1,
                        .documentType,
                        isOCRCorrectionEnabled
                    )
                ]
            )
        }
    }

    func testCreateTD1() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldCreator.createStringField = { @Sendable lines, format, type, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, type, isOCRCorrectionEnabled)) }
                return .init(value: "St", rawValue: "StringRawValue<<", checkDigit: nil, type: .documentNumber)
            }
            $0.fieldCreator.createDateField = { @Sendable lines, format, dateType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .date(dateType), isOCRCorrectionEnabled)) }
                return .init(value: .init(timeIntervalSince1970: 0), rawValue: "DateRawValue<<", checkDigit: nil, type: .date(.birth))
            }
            $0.fieldCreator.createNamesField = { @Sendable lines, format, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .names, isOCRCorrectionEnabled)) }
                return .init(value: .init(surnames: "surnames", givenNames: "given names"), rawValue: "NamesRawValue<<", checkDigit: nil, type: .names)
            }
            $0.fieldCreator.createIntField = { @Sendable lines, format, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .finalCheckDigit, isOCRCorrectionEnabled)) }
                return .init(value: 0, rawValue: "IntRawValue<<", checkDigit: nil, type: .finalCheckDigit)
            }

            $0.validator.isCompositionValid = { @Sendable fields, checkDigit in
                let stringFields = fields.map { field in
                    if let stringField = field as? Field<String> {
                        return stringField
                    } else if let dateField = field as? Field<Date> {
                        return .init(
                            value: dateField.value.formatted(),
                            rawValue: dateField.rawValue,
                            checkDigit: dateField.checkDigit,
                            type: dateField.type
                        )
                    } else {
                        let errorMessage = "Unexpected field type"
                        XCTFail(errorMessage)
                        fatalError(errorMessage)
                    }
                }

                events.withValue { $0.append(.validateComposition(stringFields, checkDigit: checkDigit)) }

                return true
            }
        } operation: {
            let mrzLines = ["I<UTOD231458907<<<<<<<<<<<<<<<", "7408122X1204159UTO<<<<<<<<<<<6", "ERIKSSON<<ANNA<MARIA<<<<<<<<<<"]
            let isOCRCorrectionEnabled = false

            XCTAssertEqual(
                MRZCodeCreator.liveValue.create(
                    mrzLines: mrzLines,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ),
                .init(
                    mrzKey: "StDateRawValue<<DateRawValue<<",
                    format: .td1,
                    documentType: .undefined,
                    documentTypeAdditional: "t",
                    countryCode: "St",
                    names: .init(surnames: "surnames", givenNames: "given names"),
                    documentNumber: "St",
                    nationalityCountryCode: "St",
                    birthdate: .init(timeIntervalSince1970: 0),
                    sex: .unspecified,
                    expiryDate: .init(timeIntervalSince1970: 0),
                    optionalData: "St",
                    optionalData2: "St"
                )
            )

            let createFieldEvent: (_ fieldType: FieldType) -> Event = {
                .createField(
                    mrzLines,
                    .td1,
                    $0,
                    isOCRCorrectionEnabled
                )
            }
            expectNoDifference(
                events.value,
                [
                    createFieldEvent(.documentType),
                    createFieldEvent(.countryCode),
                    createFieldEvent(.documentNumber),
                    createFieldEvent(.date(.birth)),
                    createFieldEvent(.date(.expiry)),
                    createFieldEvent(.sex),
                    createFieldEvent(.nationality),
                    createFieldEvent(.names),
                    createFieldEvent(.optionalData(.one)),
                    createFieldEvent(.optionalData(.two)),
                    createFieldEvent(.finalCheckDigit),
                    .validateComposition([
                        .init(value: "St", rawValue: "StringRawValue<<", checkDigit: nil, type: .documentNumber),
                        .init(value: "St", rawValue: "StringRawValue<<", checkDigit: nil, type: .documentNumber),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: nil, type: .date(.birth)),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: nil, type: .date(.birth)),
                        .init(value: "St", rawValue: "StringRawValue<<", checkDigit: nil, type: .documentNumber)
                    ], checkDigit: 0)
                ]
            )
        }
    }

    func testCreateTD2CompositionNotValidOCRCorrectionDisabled() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldCreator.createStringField = { @Sendable lines, format, type, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, type, isOCRCorrectionEnabled)) }
                return .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber)
            }
            $0.fieldCreator.createDateField = { @Sendable lines, format, dateType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .date(dateType), isOCRCorrectionEnabled)) }
                return .init(value: .init(timeIntervalSince1970: 0), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.birth))
            }
            $0.fieldCreator.createNamesField = { @Sendable lines, format, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .names, isOCRCorrectionEnabled)) }
                return .init(value: .init(surnames: "surnames", givenNames: "given names"), rawValue: "NamesRawValue<<", checkDigit: 0, type: .names)
            }
            $0.fieldCreator.createIntField = { @Sendable lines, format, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .finalCheckDigit, isOCRCorrectionEnabled)) }
                return .init(value: 0, rawValue: "IntRawValue<<", checkDigit: 0, type: .finalCheckDigit)
            }

            $0.validator.isCompositionValid = { @Sendable fields, checkDigit in
                let stringFields = fields.map { field in
                    if let stringField = field as? Field<String> {
                        return stringField
                    } else if let dateField = field as? Field<Date> {
                        return .init(
                            value: dateField.value.formatted(),
                            rawValue: dateField.rawValue,
                            checkDigit: dateField.checkDigit,
                            type: dateField.type
                        )
                    } else {
                        let errorMessage = "Unexpected field type"
                        XCTFail(errorMessage)
                        fatalError(errorMessage)
                    }
                }

                events.withValue { $0.append(.validateComposition(stringFields, checkDigit: checkDigit)) }

                return false
            }
        } operation: {
            let mrzLines = ["IRUTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<", "D231458907UTO7408122F1204159<<<<<<<6"]
            let isOCRCorrectionEnabled = false

            XCTAssertNil(
                MRZCodeCreator.liveValue.create(
                    mrzLines: mrzLines,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                )
            )

            let createFieldEvent: (_ fieldType: FieldType) -> Event = {
                .createField(
                    mrzLines,
                    .td2(isVisaDocument: false),
                    $0,
                    isOCRCorrectionEnabled
                )
            }
            expectNoDifference(
                events.value,
                [
                    createFieldEvent(.documentType),
                    createFieldEvent(.countryCode),
                    createFieldEvent(.documentNumber),
                    createFieldEvent(.date(.birth)),
                    createFieldEvent(.date(.expiry)),
                    createFieldEvent(.sex),
                    createFieldEvent(.nationality),
                    createFieldEvent(.names),
                    createFieldEvent(.optionalData(.one)),
                    createFieldEvent(.optionalData(.two)),
                    createFieldEvent(.finalCheckDigit),
                    .validateComposition([
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.birth)),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.birth)),
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber),
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber)
                    ], checkDigit: 0)
                ]
            )
        }
    }

    func testCreateTD3CompositionNotValidOCRCorrectionEnabled() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldCreator.createStringField = { @Sendable lines, format, type, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, type, isOCRCorrectionEnabled)) }
                return .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber)
            }
            $0.fieldCreator.createDateField = { @Sendable lines, format, dateType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .date(dateType), isOCRCorrectionEnabled)) }
                return .init(value: .init(timeIntervalSince1970: 0), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.birth))
            }
            $0.fieldCreator.createNamesField = { @Sendable lines, format, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .names, isOCRCorrectionEnabled)) }
                return .init(value: .init(surnames: "surnames", givenNames: "given names"), rawValue: "NamesRawValue<<", checkDigit: 0, type: .names)
            }
            $0.fieldCreator.createIntField = { @Sendable lines, format, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .finalCheckDigit, isOCRCorrectionEnabled)) }
                return .init(value: 0, rawValue: "IntRawValue<<", checkDigit: 0, type: .finalCheckDigit)
            }

            $0.validator.isCompositionValid = { @Sendable fields, checkDigit in
                let stringFields = fields.map { field in
                    if let stringField = field as? Field<String> {
                        return stringField
                    } else if let dateField = field as? Field<Date> {
                        return .init(
                            value: dateField.value.formatted(),
                            rawValue: dateField.rawValue,
                            checkDigit: dateField.checkDigit,
                            type: dateField.type
                        )
                    } else {
                        let errorMessage = "Unexpected field type"
                        XCTFail(errorMessage)
                        fatalError(errorMessage)
                    }
                }

                events.withValue { $0.append(.validateComposition(stringFields, checkDigit: checkDigit)) }

                return false
            }
            $0.ocrCorrector.findMatchingStrings = { @Sendable strings, isCorrectCombination in
                events.withValue { $0.append(.findMatchingStrings(strings, isCorrectCombination(["test", "test", "test"]))) }
                return ["test", "test", "test"]
            }
        } operation: {
            let mrzLines = ["_<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<", "L898902C36UTO7408122F1204159ZE184226B<<<<<10"]
            let isOCRCorrectionEnabled = true

            XCTAssertEqual(
                MRZCodeCreator.liveValue.create(
                    mrzLines: mrzLines,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ),
                .init(
                    mrzKey: "test0DateRawValue<<0DateRawValue<<0",
                    format: .td3(isVisaDocument: false),
                    documentType: .undefined,
                    documentTypeAdditional: nil,
                    countryCode: "StringValue",
                    names: .init(surnames: "surnames", givenNames: "given names"),
                    documentNumber: "test",
                    nationalityCountryCode: "StringValue",
                    birthdate: .init(timeIntervalSince1970: 0),
                    sex: .unspecified,
                    expiryDate: .init(timeIntervalSince1970: 0),
                    optionalData: "StringValue",
                    optionalData2: "StringValue"
                )
            )

            let createFieldEvent: (_ fieldType: FieldType) -> Event = {
                .createField(
                    mrzLines,
                    .td3(isVisaDocument: false),
                    $0,
                    isOCRCorrectionEnabled
                )
            }
            expectNoDifference(
                events.value,
                [
                    createFieldEvent(.documentType),
                    createFieldEvent(.countryCode),
                    createFieldEvent(.documentNumber),
                    createFieldEvent(.date(.birth)),
                    createFieldEvent(.date(.expiry)),
                    createFieldEvent(.sex),
                    createFieldEvent(.nationality),
                    createFieldEvent(.names),
                    createFieldEvent(.optionalData(.one)),
                    createFieldEvent(.optionalData(.two)),
                    createFieldEvent(.finalCheckDigit),
                    .validateComposition([
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.birth)),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.birth)),
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber),
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber)
                    ], checkDigit: 0),
                    .findMatchingStrings(
                        [
                            "StringRawValue<<",
                            "StringRawValue<<",
                            "StringRawValue<<"
                        ],
                        false
                    )
                ]
            )
        }
    }

    func testCreateMRVACompositionNotValidOCRCorrectionEnabledNotAbleToFindMatchingStrings() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldCreator.createStringField = { @Sendable lines, format, type, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, type, isOCRCorrectionEnabled)) }
                return .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber)
            }
            $0.fieldCreator.createDateField = { @Sendable lines, format, dateType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .date(dateType), isOCRCorrectionEnabled)) }
                return .init(value: .init(timeIntervalSince1970: 0), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.birth))
            }
            $0.fieldCreator.createNamesField = { @Sendable lines, format, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .names, isOCRCorrectionEnabled)) }
                return .init(value: .init(surnames: "surnames", givenNames: "given names"), rawValue: "NamesRawValue<<", checkDigit: 0, type: .names)
            }
            $0.fieldCreator.createIntField = { @Sendable lines, format, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .finalCheckDigit, isOCRCorrectionEnabled)) }
                return .init(value: 0, rawValue: "IntRawValue<<", checkDigit: 0, type: .finalCheckDigit)
            }

            $0.validator.isCompositionValid = { @Sendable fields, checkDigit in
                let stringFields = fields.map { field in
                    if let stringField = field as? Field<String> {
                        return stringField
                    } else if let dateField = field as? Field<Date> {
                        return .init(
                            value: dateField.value.formatted(),
                            rawValue: dateField.rawValue,
                            checkDigit: dateField.checkDigit,
                            type: dateField.type
                        )
                    } else {
                        let errorMessage = "Unexpected field type"
                        XCTFail(errorMessage)
                        fatalError(errorMessage)
                    }
                }

                events.withValue { $0.append(.validateComposition(stringFields, checkDigit: checkDigit)) }

                return false
            }
            $0.ocrCorrector.findMatchingStrings = { @Sendable strings, isCorrectCombination in
                events.withValue { $0.append(.findMatchingStrings(strings, isCorrectCombination(["test", "test", "test"]))) }
                return nil
            }
        } operation: {
            let mrzLines = ["V<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<", "L8988901C4XXX4009078F96121096ZE184226B<<<<<<"]
            let isOCRCorrectionEnabled = true

            XCTAssertNil(
                MRZCodeCreator.liveValue.create(
                    mrzLines: mrzLines,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                )
            )

            let createFieldEvent: (_ fieldType: FieldType) -> Event = {
                .createField(
                    mrzLines,
                    .td3(isVisaDocument: true),
                    $0,
                    isOCRCorrectionEnabled
                )
            }
            expectNoDifference(
                events.value,
                [
                    createFieldEvent(.documentType),
                    createFieldEvent(.countryCode),
                    createFieldEvent(.documentNumber),
                    createFieldEvent(.date(.birth)),
                    createFieldEvent(.date(.expiry)),
                    createFieldEvent(.sex),
                    createFieldEvent(.nationality),
                    createFieldEvent(.names),
                    createFieldEvent(.optionalData(.one)),
                    createFieldEvent(.optionalData(.two)),
                    createFieldEvent(.finalCheckDigit),
                    .validateComposition([
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.birth)),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.birth)),
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber),
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber)
                    ], checkDigit: 0),
                    .findMatchingStrings(
                        [
                            "StringRawValue<<",
                            "StringRawValue<<",
                            "StringRawValue<<"
                        ],
                        false
                    )
                ]
            )
        }
    }
}
