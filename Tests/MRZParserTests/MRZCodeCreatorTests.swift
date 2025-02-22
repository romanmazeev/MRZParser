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
        case createDocumentNumberField(_ lines: [String], _ format: MRZCode.Format, _ russianNationalPassportHiddenCharacter: Character?, _ isOCRCorrectionEnabled: Bool)
        case createNamesField(_ lines: [String], _ format: MRZCode.Format, _ isRussianNationalPassport: Bool, _ isOCRCorrectionEnabled: Bool)
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

    func testCreateTD1NoDocumentTypeField() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldCreator.createCharacterField = { @Sendable lines, format, type, isOCRCorrectionEnabled in
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

    func testCreateTD1NoNamesField() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldCreator.createStringField = { @Sendable lines, format, type, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, type, isOCRCorrectionEnabled)) }
                return .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: type)
            }
            $0.fieldCreator.createCharacterField = { @Sendable lines, format, type, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, type, isOCRCorrectionEnabled)) }
                if type == .documentTypeAdditional {
                    return nil
                } else {
                    return .init(value: "S", rawValue: "StringRawValue<<", checkDigit: 0, type: type)
                }
            }
            $0.fieldCreator.createDateField = { @Sendable lines, format, dateType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .date(dateType), isOCRCorrectionEnabled)) }
                return .init(value: .init(timeIntervalSince1970: 0), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(dateType))
            }
            $0.fieldCreator.createNamesField = { @Sendable lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createNamesField(lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled)) }
                return nil
            }
            $0.fieldCreator.createFinalCheckDigitField = { @Sendable lines, format, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .finalCheckDigit, isOCRCorrectionEnabled)) }
                return .init(value: 0, rawValue: "IntRawValue<<", checkDigit: 0, type: .finalCheckDigit)
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
                    createFieldEvent(.date(.birth)),
                    createFieldEvent(.sex),
                    createFieldEvent(.nationality),
                    createFieldEvent(.date(.expiry)),
                    createFieldEvent(.documentTypeAdditional),
                    createFieldEvent(.optionalData(.one)),
                    createFieldEvent(.optionalData(.two)),
                    createFieldEvent(.finalCheckDigit),
                    .createNamesField(mrzLines, .td1, false, isOCRCorrectionEnabled)
                ]
            )
        }
    }

    func testCreateTD1() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.fieldCreator.createStringField = { @Sendable lines, format, type, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, type, isOCRCorrectionEnabled)) }
                return .init(value: "RUS", rawValue: "StringRawValue<<", checkDigit: nil, type: type)
            }
            $0.fieldCreator.createDocumentNumberField = { @Sendable lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createDocumentNumberField(lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled)) }
                return .init(value: "St", rawValue: "StringRawValue<<", checkDigit: nil, type: .documentNumber)
            }
            $0.fieldCreator.createCharacterField = { @Sendable lines, format, type, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, type, isOCRCorrectionEnabled)) }

                switch type {
                case .documentType:
                    return .init(value: "P", rawValue: "StringRawValue<<", checkDigit: nil, type: .documentType)
                case .documentTypeAdditional:
                    return .init(value: "N", rawValue: "StringRawValue<<", checkDigit: nil, type: .documentTypeAdditional)
                default:
                    return .init(value: "S", rawValue: "StringRawValue<<", checkDigit: nil, type: type)
                }
            }
            $0.fieldCreator.createDateField = { @Sendable lines, format, dateType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .date(dateType), isOCRCorrectionEnabled)) }
                return .init(value: .init(timeIntervalSince1970: 0), rawValue: "DateRawValue<<", checkDigit: nil, type: .date(dateType))
            }
            $0.fieldCreator.createNamesField = { @Sendable lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createNamesField(lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled)) }
                return .init(value: .init(surnames: "surnames", givenNames: "given names"), rawValue: "NamesRawValue<<", checkDigit: nil, type: .names)
            }
            $0.fieldCreator.createFinalCheckDigitField = { @Sendable lines, format, isOCRCorrectionEnabled in
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
                    mrzKey: "StringRawValue<<DateRawValue<<DateRawValue<<",
                    format: .td1,
                    documentType: .passport,
                    documentTypeAdditional: .national,
                    countryCode: "RUS",
                    names: .init(surnames: "surnames", givenNames: "given names"),
                    documentNumber: "St",
                    nationalityCountryCode: "RUS",
                    birthdate: .init(timeIntervalSince1970: 0),
                    sex: .unspecified,
                    expiryDate: .init(timeIntervalSince1970: 0),
                    optionalData: "RUS",
                    optionalData2: "RUS"
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
                    createFieldEvent(.date(.birth)),
                    createFieldEvent(.sex),
                    createFieldEvent(.nationality),
                    createFieldEvent(.date(.expiry)),
                    createFieldEvent(.documentTypeAdditional),
                    createFieldEvent(.optionalData(.one)),
                    createFieldEvent(.optionalData(.two)),
                    createFieldEvent(.finalCheckDigit),
                    .createNamesField(mrzLines, .td1, true, isOCRCorrectionEnabled),
                    .createDocumentNumberField(mrzLines, .td1, "R", isOCRCorrectionEnabled),
                    .validateComposition([
                        .init(value: "St", rawValue: "StringRawValue<<", checkDigit: nil, type: .documentNumber),
                        .init(value: "RUS", rawValue: "StringRawValue<<", checkDigit: nil, type: .optionalData(.one)),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: nil, type: .date(.birth)),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: nil, type: .date(.expiry)),
                        .init(value: "RUS", rawValue: "StringRawValue<<", checkDigit: nil, type: .optionalData(.two))
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
                return .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: type)
            }
            $0.fieldCreator.createDocumentNumberField = { @Sendable lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createDocumentNumberField(lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled)) }
                return .init(value: "St", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber)
            }
            $0.fieldCreator.createCharacterField = { @Sendable lines, format, type, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, type, isOCRCorrectionEnabled)) }
                return .init(value: "S", rawValue: "StringRawValue<<", checkDigit: 0, type: type)
            }
            $0.fieldCreator.createDateField = { @Sendable lines, format, dateType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .date(dateType), isOCRCorrectionEnabled)) }
                return .init(value: .init(timeIntervalSince1970: 0), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(dateType))
            }
            $0.fieldCreator.createNamesField = { @Sendable lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createNamesField(lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled)) }
                return .init(value: .init(surnames: "surnames", givenNames: "given names"), rawValue: "NamesRawValue<<", checkDigit: 0, type: .names)
            }
            $0.fieldCreator.createFinalCheckDigitField = { @Sendable lines, format, isOCRCorrectionEnabled in
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
                    createFieldEvent(.date(.birth)),
                    createFieldEvent(.sex),
                    createFieldEvent(.nationality),
                    createFieldEvent(.date(.expiry)),
                    createFieldEvent(.documentTypeAdditional),
                    createFieldEvent(.optionalData(.one)),
                    createFieldEvent(.optionalData(.two)),
                    createFieldEvent(.finalCheckDigit),
                    .createNamesField(mrzLines, .td2(isVisaDocument: false), false, isOCRCorrectionEnabled),
                    .createDocumentNumberField(mrzLines, .td2(isVisaDocument: false), nil, isOCRCorrectionEnabled),
                    .validateComposition([
                        .init(value: "St", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.birth)),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.expiry)),
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .optionalData(.one)),
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .optionalData(.two))
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
                return .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: type)
            }
            $0.fieldCreator.createDocumentNumberField = { @Sendable lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createDocumentNumberField(lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled)) }
                return .init(value: "St", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber)
            }
            $0.fieldCreator.createCharacterField = { @Sendable lines, format, type, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, type, isOCRCorrectionEnabled)) }
                return .init(value: "S", rawValue: "StringRawValue<<", checkDigit: 0, type: type)
            }
            $0.fieldCreator.createDateField = { @Sendable lines, format, dateType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .date(dateType), isOCRCorrectionEnabled)) }
                return .init(value: .init(timeIntervalSince1970: 0), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(dateType))
            }
            $0.fieldCreator.createNamesField = { @Sendable lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createNamesField(lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled)) }
                return .init(value: .init(surnames: "surnames", givenNames: "given names"), rawValue: "NamesRawValue<<", checkDigit: 0, type: .names)
            }
            $0.fieldCreator.createFinalCheckDigitField = { @Sendable lines, format, isOCRCorrectionEnabled in
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
                    optionalData: "test",
                    optionalData2: "test"
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
                    createFieldEvent(.date(.birth)),
                    createFieldEvent(.sex),
                    createFieldEvent(.nationality),
                    createFieldEvent(.date(.expiry)),
                    createFieldEvent(.documentTypeAdditional),
                    createFieldEvent(.optionalData(.one)),
                    createFieldEvent(.optionalData(.two)),
                    createFieldEvent(.finalCheckDigit),
                    .createNamesField(mrzLines, .td3(isVisaDocument: false), false, isOCRCorrectionEnabled),
                    .createDocumentNumberField(mrzLines, .td3(isVisaDocument: false), nil, isOCRCorrectionEnabled),
                    .validateComposition([
                        .init(value: "St", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.birth)),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.expiry)),
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .optionalData(.one)),
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .optionalData(.two))
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
                return .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: type)
            }
            $0.fieldCreator.createDocumentNumberField = { @Sendable lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createDocumentNumberField(lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled)) }
                return .init(value: "St", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber)
            }
            $0.fieldCreator.createCharacterField = { @Sendable lines, format, type, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, type, isOCRCorrectionEnabled)) }
                return .init(value: "S", rawValue: "StringRawValue<<", checkDigit: 0, type: type)
            }
            $0.fieldCreator.createDateField = { @Sendable lines, format, dateType, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createField(lines, format, .date(dateType), isOCRCorrectionEnabled)) }
                return .init(value: .init(timeIntervalSince1970: 0), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(dateType))
            }
            $0.fieldCreator.createNamesField = { @Sendable lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled in
                events.withValue { $0.append(.createNamesField(lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled)) }
                return .init(value: .init(surnames: "surnames", givenNames: "given names"), rawValue: "NamesRawValue<<", checkDigit: 0, type: .names)
            }
            $0.fieldCreator.createFinalCheckDigitField = { @Sendable lines, format, isOCRCorrectionEnabled in
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
                    createFieldEvent(.date(.birth)),
                    createFieldEvent(.sex),
                    createFieldEvent(.nationality),
                    createFieldEvent(.date(.expiry)),
                    createFieldEvent(.documentTypeAdditional),
                    createFieldEvent(.optionalData(.one)),
                    createFieldEvent(.optionalData(.two)),
                    createFieldEvent(.finalCheckDigit),
                    .createNamesField(mrzLines, .td3(isVisaDocument: true), false, isOCRCorrectionEnabled),
                    .createDocumentNumberField(mrzLines, .td3(isVisaDocument: true), nil, isOCRCorrectionEnabled),
                    .validateComposition([
                        .init(value: "St", rawValue: "StringRawValue<<", checkDigit: 0, type: .documentNumber),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.birth)),
                        .init(value: Date(timeIntervalSince1970: 0).formatted(), rawValue: "DateRawValue<<", checkDigit: 0, type: .date(.expiry)),
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .optionalData(.one)),
                        .init(value: "StringValue", rawValue: "StringRawValue<<", checkDigit: 0, type: .optionalData(.two))
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
