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

    var createNamesField: @Sendable (
        _ lines: [String],
        _ format: MRZCode.Format,
        _ isOCRCorrectionEnabled: Bool
    ) -> Field<MRZCode.Names>?

    var createDateField: @Sendable (
        _ lines: [String],
        _ format: MRZCode.Format,
        _ dateFieldType: FieldType.DateFieldType,
        _ isOCRCorrectionEnabled: Bool
    ) -> Field<Date>?

    var createIntField: @Sendable (
        _ lines: [String],
        _ format: MRZCode.Format,
        _ isOCRCorrectionEnabled: Bool
    ) -> Field<Int>?
}

extension FieldCreator: DependencyKey {
    static var liveValue: Self {
        @Sendable
        func getRawValueAndCheckDigit(
            from lines: [String],
            format: MRZCode.Format,
            fieldType: FieldType,
            isOCRCorrectionEnabled: Bool
        ) -> (String, Int?)? {
            guard let position = fieldType.position(for: format) else {
                return nil
            }

            let line = lines[position.line]
            guard let rawValue = getRawValue(
                from: line,
                range: position.range,
                ocrCorrectionType: {
                    guard isOCRCorrectionEnabled else {
                        return nil
                    }

                    guard fieldType != .sex else {
                        return .sex
                    }

                    switch fieldType.contentType {
                    case .digits:
                        return .digits
                    case .letters:
                        return .letters
                    case .mixed:
                        return nil
                    }
                }()
            ) else {
                return nil
            }

            return validateAndCorrectIfNeeded(
                line: line,
                rawValue: rawValue,
                format: format,
                position: position,
                isOCRCorrectionEnabled: isOCRCorrectionEnabled,
                fieldType: fieldType
            )
        }

        @Sendable
        func validateAndCorrectIfNeeded(
            line: String,
            rawValue: String,
            format: MRZCode.Format,
            position: FieldType.FieldPosition,
            isOCRCorrectionEnabled: Bool,
            fieldType: FieldType
        ) -> (String, Int?)? {
            if fieldType.shouldValidate(mrzFormat: format) {
                guard let checkDigit = getCheckDigit(
                    from: line,
                    endIndex: position.range.upperBound,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ) else {
                    return nil
                }

                @Dependency(\.validator) var validator
                if !validator.isValueValid(rawValue: rawValue, checkDigit: checkDigit) {
                    if isOCRCorrectionEnabled, fieldType.contentType == .mixed {
                        @Dependency(\.ocrCorrector) var ocrCorrector
                        guard let bruteForcedString = ocrCorrector.findMatchingStrings(strings: [rawValue], isCorrectCombination: {
                            guard let currentString = $0.first else {
                                return false
                            }

                            return validator.isValueValid(rawValue: currentString, checkDigit: checkDigit)
                        })?.first else {
                            return nil
                        }

                        return (bruteForcedString, checkDigit)
                    } else {
                        return nil
                    }
                } else {
                    return (rawValue, checkDigit)
                }
            } else {
                return (rawValue, nil)
            }
        }

        @Sendable
        func getRawValue(
            from string: String,
            range: Range<Int>,
            ocrCorrectionType: OCRCorrector.CorrectionType?
        ) -> String? {
            let value = string.substring(range.lowerBound, to: range.upperBound - 1)
            let correctedValue = {
                if let ocrCorrectionType {
                    @Dependency(\.ocrCorrector) var ocrCorrector
                    return ocrCorrector.correct(string: value, correctionType: ocrCorrectionType)
                } else {
                    return value
                }
            }()

            if let ocrCorrectionType, !ocrCorrectionType.characterSet.isSuperset(of: CharacterSet(charactersIn: correctedValue.replace("<", with: ""))) {
                return nil
            }

            return correctedValue
        }

        @Sendable
        func getCheckDigit(
            from string: String,
            endIndex: Int,
            isOCRCorrectionEnabled: Bool
        ) -> Int? {
            let value = string.substring(endIndex, to: endIndex)
            let correctedValue = {
                if isOCRCorrectionEnabled {
                    @Dependency(\.ocrCorrector) var ocrCorrector
                    return ocrCorrector.correct(string: value, correctionType: .digits)
                } else {
                    return value
                }
            }()

            return Int(correctedValue)
        }

        @Sendable
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

        return .init(
            createStringField: { lines, format, type, isOCRCorrectionEnabled in
                guard let (rawValue, checkDigit) = getRawValueAndCheckDigit(
                    from: lines,
                    format: format,
                    fieldType: type,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ), let value = rawValue.fieldValue else {
                    return nil
                }

                return .init(value: value, rawValue: rawValue, checkDigit: checkDigit, type: type)
            },
            createNamesField: { lines, format, isOCRCorrectionEnabled in
                let type: FieldType = .names
                guard let (rawValue, checkDigit) = getRawValueAndCheckDigit(
                    from: lines,
                    format: format,
                    fieldType: type,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ) else {
                    return nil
                }

                let identifiers = rawValue.trimmingFillers
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
                let type: FieldType = .date(dateFieldType)
                guard let (rawValue, checkDigit) = getRawValueAndCheckDigit(
                    from: lines,
                    format: format,
                    fieldType: type,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ), let dateValue = date(from: rawValue, dateFieldType: dateFieldType) else {
                    return nil
                }

                return .init(value: dateValue, rawValue: rawValue, checkDigit: checkDigit, type: type)
            },
            createIntField: { lines, format, isOCRCorrectionEnabled in
                let type: FieldType = .finalCheckDigit
                guard let (rawValue, checkDigit) = getRawValueAndCheckDigit(
                    from: lines,
                    format: format,
                    fieldType: type,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ), let value = rawValue.fieldValue, let intValue = Int(value) else {
                    return nil
                }

                return .init(value: intValue, rawValue: rawValue, checkDigit: checkDigit, type: type)
            }
        )
    }
}

extension OCRCorrector.CorrectionType {
    var characterSet: CharacterSet {
        switch self {
        case .digits:
            .decimalDigits
        case .letters, .sex:
            .letters
        }
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
