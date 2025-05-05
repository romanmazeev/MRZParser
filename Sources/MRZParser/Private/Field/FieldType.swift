//
//  FieldType.swift
//  MRZParser
//
//  Created by Roman Mazeev on 09/02/2025.
//

import Foundation

enum FieldType: Hashable {
    enum DateFieldType {
        case birth
        case expiry
    }

    enum OptionalFieldType {
        case one
        case two
    }

    case documentType
    case documentSubtype
    case issuingCountryCode
    case documentNumber
    case date(DateFieldType)
    case sex
    case nationalityCountryCode
    case name
    case optionalData(OptionalFieldType)
    case finalCheckDigit
}

extension FieldType {
    struct FieldPosition: Equatable {
        /// Line number in MRZ code where the field is located (starting from 0)
        let line: Int
        /// Range of characters in the line where the field is located
        let range: Range<Int>

        init(line: Int, range: Range<Int>) {
            self.line = line
            self.range = range
        }
    }
    func position(for format: MRZCode.Format) -> FieldPosition? {
        switch self {
        case .documentType:
            return .init(line: 0, range: 0..<1)
        case .documentSubtype:
            return .init(line: 0, range: 1..<2)
        case .issuingCountryCode:
            return .init(line: 0, range: 2..<5)
        case .documentNumber:
            switch format {
            case .td1:
                return .init(line: 0, range: 5..<14)
            case .td2, .td3:
                return .init(line: 1, range: 0..<9)
            }
        case .date(.birth):
            switch format {
            case .td1:
                return .init(line: 1, range: 0..<6)
            case .td2, .td3:
                return .init(line: 1, range: 13..<19)
            }
        case .date(.expiry):
            switch format {
            case .td1:
                return .init(line: 1, range: 8..<14)
            case .td2, .td3:
                return .init(line: 1, range: 21..<27)
            }
        case .sex:
            switch format {
            case .td1:
                return .init(line: 1, range: 7..<8)
            case .td2, .td3:
                return .init(line: 1, range: 20..<21)
            }
        case .nationalityCountryCode:
            switch format {
            case .td1:
                return .init(line: 1, range: 15..<18)
            case .td2, .td3:
                return .init(line: 1, range: 10..<13)
            }
        case .name:
            switch format {
            case .td1:
                return .init(line: 2, range: 0..<29)
            case .td2:
                return .init(line: 0, range: 5..<36)
            case .td3:
                return .init(line: 0, range: 5..<44)
            }
        case .optionalData(.one):
            switch format {
            case .td1:
                return .init(line: 0, range: 15..<30)
            case .td2(let isVisaDocument):
                return .init(line: 1, range: 28..<(isVisaDocument ? 36 : 35))
            case .td3(let isVisaDocument):
                return .init(line: 1, range: 28..<(isVisaDocument ? 44 : 42))
            }
        case .optionalData(.two):
            switch format {
            case .td1:
                return .init(line: 1, range: 18..<29)
            case .td2, .td3:
                return nil
            }
        case .finalCheckDigit:
            switch format {
            case .td1:
                return .init(line: 1, range: 29..<30)
            case .td2(let isVisaDocument) where !isVisaDocument:
                return .init(line: 1, range: 35..<36)
            case .td3(let isVisaDocument) where !isVisaDocument:
                return .init(line: 1, range: 43..<44)
            default:
                return nil
            }
        }
    }
}

extension FieldType {
    enum ContentType {
        case letters
        case digits
        case mixed
        case sex

        var characterSet: CharacterSet? {
            switch self {
            case .digits:
                .decimalDigits
            case .letters, .sex:
                .letters
            case .mixed:
                nil
            }
        }
    }

    func contentType(
        isRussianNationalPassport: Bool
    ) -> ContentType {
        switch self {
        case .name where isRussianNationalPassport:
            .mixed
        case .documentNumber where isRussianNationalPassport:
            .digits
        case .optionalData(.one) where isRussianNationalPassport:
            .digits
        case .documentType, .documentSubtype, .issuingCountryCode, .nationalityCountryCode, .name:
            .letters
        case .optionalData, .documentNumber:
            .mixed
        case .date, .finalCheckDigit:
            .digits
        case .sex:
            .sex
        }
    }
}

extension FieldType {
    /// Returns fields that should be validated using final check digit
    static func validateFinalCheckDigitFields(mrzFormat: MRZCode.Format) -> [Self] {
        switch mrzFormat {
        case .td1:
            [.documentNumber, .optionalData(.one), .date(.birth), .date(.expiry), .optionalData(.two)]
        case .td2, .td3:
            [.documentNumber, .date(.birth), .date(.expiry), .optionalData(.one), .optionalData(.two)]
        }
    }

    /// If true, the field is followed by a check digit and should be validated
    func shouldValidateCheckDigit(mrzFormat: MRZCode.Format) -> Bool {
        switch self {
        case .documentType, .documentSubtype, .issuingCountryCode, .sex, .nationalityCountryCode, .name, .optionalData(.two), .finalCheckDigit:
            return false
        case .documentNumber, .date:
            return true
        case .optionalData(.one):
            switch mrzFormat {
            case .td3(let isVisaDocument) where !isVisaDocument:
                return true
            default:
                return false
            }
        }
    }
}
