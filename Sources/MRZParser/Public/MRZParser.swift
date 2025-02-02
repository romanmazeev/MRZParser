//
//  MRZParser.swift
//
//
//  Created by Roman Mazeev on 15.06.2021.
//

import Foundation

public struct MRZParser {
    public static func parse(mrzLines: [String], isOCRCorrectionEnabled: Bool) -> MRZResult? {
        guard let format = createMRZFormat(from: mrzLines) else { return nil }

        guard var mrzCode = MRZCode(
            from: mrzLines,
            format: format,
            isOCRCorrectionEnabled: isOCRCorrectionEnabled
        ), mrzCode.allFieldsAreValid else {
            return nil
        }

        if !mrzCode.isCompositionValid {
            if isOCRCorrectionEnabled {
                if !mrzCode.bruteForceCorrectOptionalDataIfNeeded() {
                    return nil
                }
            } else {
                return nil
            }
        }

        let documentType = MRZResult.DocumentType.allCases.first {
            $0.identifier == mrzCode.documentTypeField.first
        } ?? .undefined
        let documentTypeAdditional = mrzCode.documentTypeField.count == 2
            ? mrzCode.documentTypeField.last
            : nil
        let sex = MRZResult.Sex.allCases.first {
            $0.identifier.contains(mrzCode.sexField)
        } ?? .unspecified

        let mrzKey = mrzCode.documentNumberField.value + (mrzCode.documentNumberField.checkDigit.map { String($0) } ?? "")
            + mrzCode.birthdateField.rawValue + (mrzCode.birthdateField.checkDigit.map { String($0) } ?? "")
            + mrzCode.expiryDateField.rawValue + (mrzCode.expiryDateField.checkDigit.map { String($0) } ?? "")

        return .init(
            mrzKey: mrzKey,
            format: mrzCode.format,
            documentType: documentType,
            documentTypeAdditional: documentTypeAdditional,
            countryCode: mrzCode.countryCodeField,
            surnames: mrzCode.namesField.surnames,
            givenNames: mrzCode.namesField.givenNames,
            documentNumber: mrzCode.documentNumberField.value,
            nationalityCountryCode: mrzCode.nationalityField,
            birthdate: mrzCode.birthdateField.value,
            sex: sex,
            expiryDate: mrzCode.expiryDateField.value,
            optionalData: mrzCode.optionalDataField?.value,
            optionalData2: mrzCode.optionalData2Field?.value
        )
    }

    public static func parse(mrzString: String, isOCRCorrectionEnabled: Bool) -> MRZResult? {
        return parse(mrzLines: mrzString.components(separatedBy: "\n"), isOCRCorrectionEnabled: isOCRCorrectionEnabled)
    }

    // MARK: MRZ-Format detection
    private static func createMRZFormat(from mrzLines: [String]) -> MRZFormat? {
        switch mrzLines.count {
        case MRZFormat.td2.linesCount,  MRZFormat.td3.linesCount:
            return [.td2, .td3].first(where: { $0.lineLength == uniformedLineLength(for: mrzLines) })
        case MRZFormat.td1.linesCount:
            return (uniformedLineLength(for: mrzLines) == MRZFormat.td1.lineLength) ? .td1 : nil
        default:
            return nil
        }
    }

    private static func uniformedLineLength(for mrzLines: [String]) -> Int? {
        guard let lineLength = mrzLines.first?.count,
              !mrzLines.contains(where: { $0.count != lineLength }) else { return nil }
        return lineLength
    }
}
