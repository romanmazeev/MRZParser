//
//  FieldCreator.swift
//  MRZParser
//
//  Created by Roman Mazeev on 17/02/2025.
//

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct FieldCreator: Sendable {
    var createStringField: @Sendable (
        _ lines: [String],
        _ format: MRZCode.Format,
        _ type: FieldType,
        _ isOCRCorrectionEnabled: Bool
    ) -> Field<String>?

    var createDocumentNumberField: @Sendable (
        _ lines: [String],
        _ format: MRZCode.Format,
        _ russianNationalPassportHiddenCharacter: Character?,
        _ isOCRCorrectionEnabled: Bool
    ) -> Field<String>?

    var createCharacterField: @Sendable (
        _ lines: [String],
        _ format: MRZCode.Format,
        _ type: FieldType,
        _ isOCRCorrectionEnabled: Bool
    ) -> Field<Character>?

    var createNamesField: @Sendable (
        _ lines: [String],
        _ format: MRZCode.Format,
        _ isRussianNationalPassport: Bool,
        _ isOCRCorrectionEnabled: Bool
    ) -> Field<MRZCode.Names>?

    var createDateField: @Sendable (
        _ lines: [String],
        _ format: MRZCode.Format,
        _ dateFieldType: FieldType.DateFieldType,
        _ isOCRCorrectionEnabled: Bool
    ) -> Field<Date>?

    var createFinalCheckDigitField: @Sendable (
        _ lines: [String],
        _ format: MRZCode.Format,
        _ isOCRCorrectionEnabled: Bool
    ) -> Field<Int>?
}

extension FieldCreator: DependencyKey {
    static var liveValue: Self {
        .init(
            createStringField: { lines, format, type, isOCRCorrectionEnabled in
                @Dependency(\.fieldComponentsCreator) var fieldComponentsCreator
                guard let (rawValue, checkDigit) = fieldComponentsCreator.getRawValueAndCheckDigit(
                    lines: lines,
                    format: format,
                    fieldType: type,
                    rawValueOCRCorrectionType: type.contentType.correctionType,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ), let value = rawValue.fieldValue else {
                    return nil
                }

                return .init(value: value, rawValue: rawValue, checkDigit: checkDigit, type: type)
            },
            createDocumentNumberField: { lines, format, russianNationalPassportHiddenCharacter, isOCRCorrectionEnabled in
                let type: FieldType = .documentNumber
                @Dependency(\.fieldComponentsCreator) var fieldComponentsCreator
                guard let (rawValue, checkDigit) = fieldComponentsCreator.getRawValueAndCheckDigit(
                    lines: lines,
                    format: format,
                    fieldType: type,
                    rawValueOCRCorrectionType: type.contentType.correctionType,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ), var value = rawValue.fieldValue else {
                    return nil
                }

                if let russianNationalPassportHiddenCharacter {
                    value.insert(russianNationalPassportHiddenCharacter, at: value.index(value.startIndex, offsetBy: 3))
                }

                return .init(value: value, rawValue: rawValue, checkDigit: checkDigit, type: type)
            },
            createCharacterField: { lines, format, type, isOCRCorrectionEnabled in
                @Dependency(\.fieldComponentsCreator) var fieldComponentsCreator
                guard let (rawValue, checkDigit) = fieldComponentsCreator.getRawValueAndCheckDigit(
                    lines: lines,
                    format: format,
                    fieldType: type,
                    rawValueOCRCorrectionType: type == .sex ? .sex : type.contentType.correctionType,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ), let value = rawValue.fieldValue, let character = value.first else {
                    return nil
                }

                return .init(value: character, rawValue: rawValue, checkDigit: checkDigit, type: type)
            },
            createNamesField: { lines, format, isRussianNationalPassport, isOCRCorrectionEnabled in
                let type: FieldType = .names
                @Dependency(\.fieldComponentsCreator) var fieldComponentsCreator
                guard let (rawValue, checkDigit) = fieldComponentsCreator.getRawValueAndCheckDigit(
                    lines: lines,
                    format: format,
                    fieldType: type,
                    rawValueOCRCorrectionType: isRussianNationalPassport ? nil : type.contentType.correctionType,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ) else {
                    return nil
                }

                let convertedValue = {
                    if isRussianNationalPassport {
                        // Convert to cyrilic
                        @Dependency(\.cyrillicNameConverter) var cyrillicNameConverter
                        let convertedName = cyrillicNameConverter.convert(rawValue)
                        // Correct digits to english letters
                        @Dependency(\.ocrCorrector) var ocrCorrector
                        let correctedName = ocrCorrector.correct(string: convertedName, correctionType: .letters)
                        // Correct english letters to cyrilic
                        return cyrillicNameConverter.convert(correctedName)
                    } else {
                        return rawValue
                    }
                }()

                let identifiers = convertedValue.trimmingFillers
                    .components(separatedBy: "<<")
                    .map { $0.replace("<", with: " ") }

                return .init(
                    value: .init(surnames: identifiers[0], givenNames: identifiers.count > 1 ? identifiers[1] : nil),
                    rawValue: rawValue,
                    checkDigit: checkDigit,
                    type: type
                )
            },
            createDateField: { lines, format, dateFieldType, isOCRCorrectionEnabled in
                func date(from string: String, dateFieldType: FieldType.DateFieldType) -> Date? {
                    guard let parsedYear = Int(string.substring(0, to: 1)) else {
                        return nil
                    }

                    @Dependency(\.date.now) var dateNow
                    let currentCentennial = Calendar.current.component(.year, from: dateNow) / 100
                    let previousCentennial = currentCentennial - 1
                    let currentYear = Calendar.current.component(.year, from: dateNow) - currentCentennial * 100
                    let boundaryYear = currentYear + 50
                    let centennial = switch dateFieldType {
                    case .birth:
                        (parsedYear > currentYear) ? String(previousCentennial) : String(currentCentennial)
                    case .expiry:
                        parsedYear >= boundaryYear ? String(previousCentennial) : String(currentCentennial)
                    }

                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyyMMdd"
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = TimeZone(abbreviation: "GMT+0:00")
                    return formatter.date(from: centennial + string)
                }

                let type: FieldType = .date(dateFieldType)
                @Dependency(\.fieldComponentsCreator) var fieldComponentsCreator
                guard let (rawValue, checkDigit) = fieldComponentsCreator.getRawValueAndCheckDigit(
                    lines: lines,
                    format: format,
                    fieldType: type,
                    rawValueOCRCorrectionType: type.contentType.correctionType,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ), let dateValue = date(from: rawValue, dateFieldType: dateFieldType) else {
                    return nil
                }

                return .init(value: dateValue, rawValue: rawValue, checkDigit: checkDigit, type: type)
            },
            createFinalCheckDigitField: { lines, format, isOCRCorrectionEnabled in
                let type: FieldType = .finalCheckDigit
                @Dependency(\.fieldComponentsCreator) var fieldComponentsCreator
                guard let (rawValue, checkDigit) = fieldComponentsCreator.getRawValueAndCheckDigit(
                    lines: lines,
                    format: format,
                    fieldType: type,
                    rawValueOCRCorrectionType: type.contentType.correctionType,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ), let value = rawValue.fieldValue, let intValue = Int(value) else {
                    return nil
                }

                return .init(value: intValue, rawValue: rawValue, checkDigit: checkDigit, type: type)
            }
        )
    }
}

extension DependencyValues {
    var fieldCreator: FieldCreator {
        get { self[FieldCreator.self] }
        set { self[FieldCreator.self] = newValue }
    }
}

#if DEBUG
extension FieldCreator: TestDependencyKey {
    static let testValue = Self()
}
#endif
