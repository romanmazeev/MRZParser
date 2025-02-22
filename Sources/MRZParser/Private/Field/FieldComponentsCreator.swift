//
//  FieldComponentsCreator.swift
//  MRZParser
//
//  Created by Roman Mazeev on 21/02/2025.
//

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct FieldComponentsCreator: Sendable {
    var getRawValueAndCheckDigit: @Sendable (
        _ lines: [String],
        _ format: MRZCode.Format,
        _ fieldType: FieldType,
        _ rawValueOCRCorrectionType: OCRCorrector.CorrectionType?,
        _ isOCRCorrectionEnabled: Bool
    ) -> (String, Int?)?
}

extension FieldComponentsCreator: DependencyKey {
    static var liveValue: Self {
        @Sendable
        func validateAndCorrect(
            line: String,
            rawValue: String,
            position: FieldType.FieldPosition,
            contentType: FieldType.ContentType,
            isOCRCorrectionEnabled: Bool
        ) -> (String, Int)? {
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

            guard let checkDigit = getCheckDigit(
                from: line,
                endIndex: position.range.upperBound,
                isOCRCorrectionEnabled: isOCRCorrectionEnabled
            ) else {
                return nil
            }

            @Dependency(\.validator) var validator
            if !validator.isValueValid(rawValue: rawValue, checkDigit: checkDigit) {
                if isOCRCorrectionEnabled, contentType == .mixed {
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

        return .init { lines, format, fieldType, rawValueOCRCorrectionType, isOCRCorrectionEnabled in
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

                    return rawValueOCRCorrectionType
                }()
            ) else {
                return nil
            }

            guard fieldType.shouldValidate(mrzFormat: format) else {
                return (rawValue, nil)
            }

            return validateAndCorrect(
                line: line,
                rawValue: rawValue,
                position: position,
                contentType: fieldType.contentType,
                isOCRCorrectionEnabled: isOCRCorrectionEnabled
            )
        }
    }
}

private extension OCRCorrector.CorrectionType {
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
    var fieldComponentsCreator: FieldComponentsCreator {
        get { self[FieldComponentsCreator.self] }
        set { self[FieldComponentsCreator.self] = newValue }
    }
}

#if DEBUG
extension FieldComponentsCreator: TestDependencyKey {
    static let testValue = Self()
}
#endif
