//
//  MRZFieldFactory.swift
//
//
//  Created by Roman Mazeev on 15.06.2021.
//

import Foundation

struct MRZFieldFactory {
    private let isOCRCorrectionEnabled: Bool
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT+0:00")
        return formatter
    }()

    init(isOCRCorrectionEnabled: Bool) {
        self.isOCRCorrectionEnabled = isOCRCorrectionEnabled
    }

    // MARK: Basic Fields

    func createStringField(
        from string: String,
        at startIndex: Int,
        length: Int,
        ocrCorrectionType: OCRCorrectionType
    ) -> String? {
        guard let rawValue = getRawValue(from: string, startIndex: startIndex, length: length, ocrCorrectionType: ocrCorrectionType),
              let value = text(from: rawValue) else {
            return nil
        }
        return value
    }

    func createIntField(
        from string: String,
        at startIndex: Int,
        length: Int
    ) -> Int? {
        guard let rawValue = getRawValue(from: string, startIndex: startIndex, length: length, ocrCorrectionType: .digits),
              let value = text(from: rawValue) else {
            return nil
        }
        return Int(value)
    }

    func createNamesField(
        from string: String,
        at startIndex: Int,
        length: Int
    ) -> NamesField? {
        guard let rawValue = getRawValue(from: string, startIndex: startIndex, length: length, ocrCorrectionType: nil) else {
            return nil
        }
        let identifiers = rawValue.trimmingFillers
            .components(separatedBy: "<<")
            .map { $0.replace("<", with: " ") }

        guard let surnames = identifiers.first, identifiers.count > 1 else {
            return nil
        }

        return (surnames, identifiers[1])
    }

    // MARK: Validated Fields

    enum DateValidatedFieldType {
        case birthdate
        case expiryDate
    }

    func createDateValidatedField(
        from string: String,
        at startIndex: Int,
        length: Int,
        fieldType: DateValidatedFieldType
    ) -> ValidatedField<Date>? {
        guard let rawValue = getRawValue(from: string, startIndex: startIndex, length: length, ocrCorrectionType: .digits) else {
            return nil
        }
        let checkDigit = getCheckDigit(from: string, endIndex: startIndex + length)
        guard let dateValue = date(from: rawValue, fieldType: fieldType) else {
            return nil
        }
        return .init(value: dateValue, rawValue: rawValue, checkDigit: checkDigit)
    }

    func createStringValidatedField(
        from string: String,
        at startIndex: Int,
        length: Int,
        checkDigitFollows: Bool = true
    ) -> ValidatedField<String>? {
        let checkDigit = checkDigitFollows ? getCheckDigit(
            from: string,
            endIndex: startIndex + length
        ) : nil

        guard let rawValue = getRawValue(
            from: string,
            startIndex: startIndex,
            length: length,
            ocrCorrectionType: nil
        ), let value = text(from: rawValue) else {
            return nil
        }

        return .init(value: value, rawValue: rawValue, checkDigit: checkDigit)
    }

    private func getRawValue(
        from string: String,
        startIndex: Int,
        length: Int,
        ocrCorrectionType: OCRCorrectionType?
    ) -> String? {
        let endIndex = startIndex + length
        let value = string.substring(startIndex, to: (endIndex - 1))
        let correctedValue = if isOCRCorrectionEnabled, let ocrCorrectionType {
            ocrCorrectionType.replace(value)
        } else {
            value
        }

        if let ocrCorrectionType, !ocrCorrectionType.characterSet.isSuperset(of: CharacterSet(charactersIn: correctedValue.replace("<", with: ""))) {
            return nil
        }

        return correctedValue
    }

    private func getCheckDigit(
        from string: String,
        endIndex: Int
    ) -> Int? {
        let value = string.substring(endIndex, to: endIndex)
        let correctedValue = if isOCRCorrectionEnabled {
            OCRCorrectionType.digits.replace(value)
        } else {
            value
        }

        return Int(correctedValue)
    }

    private func date(from string: String, fieldType: DateValidatedFieldType) -> Date? {
        guard let parsedYear = Int(string.substring(0, to: 1)) else {
            return nil
        }

        let currentCentennial = Calendar.current.component(.year, from: Date()) / 100
        let previousCentennial = currentCentennial - 1
        let currentYear = Calendar.current.component(.year, from: Date()) - currentCentennial * 100
        let boundaryYear = currentYear + 50
        let centennial = switch fieldType {
        case .birthdate:
            (parsedYear > currentYear) ? String(previousCentennial) : String(currentCentennial)
        case .expiryDate:
            parsedYear >= boundaryYear ? String(previousCentennial) : String(currentCentennial)
        }
        return dateFormatter.date(from: centennial + string)
    }

     func text(from string: String) -> String? {
        let text = string.trimmingFillers.replace("<", with: " ")
        return text.isEmpty ? nil : text
    }
}
