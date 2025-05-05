//
//  MRZCode.swift
//  MRZParser
//
//  Created by Roman Mazeev on 15.06.2021.
//

import Dependencies
import Foundation

public struct MRZCode: Sendable, Hashable {
    public enum Format: Sendable, Hashable {
        case td1, td2(isVisaDocument: Bool), td3(isVisaDocument: Bool)
    }

    public enum DocumentType: Sendable, Hashable {
        case visa
        case passport
        case other(Character)
    }

    public enum DocumentSubtype: Sendable, Hashable {
        case national
        case other(Character)
    }

    public enum Country: Sendable, Hashable {
        case russia
        case other(String)
    }

    public enum Sex: Sendable, Hashable {
        case male
        case female
        case unspecified
        case other(Character)
    }

    public struct Name: Sendable, Hashable {
        public let surname: String
        public let givenNames: String?

        public init(surname: String, givenNames: String?) {
            self.surname = surname
            self.givenNames = givenNames
        }
    }

    public let mrzKey: String
    public let format: Format
    public let documentType: DocumentType
    public let documentSubtype: DocumentSubtype?
    public let issuingCountry: Country
    public let name: Name
    public let documentNumber: String
    public let nationalityCountryCode: String
    public let birthdate: Date
    public let sex: Sex
    public let expiryDate: Date?
    public let optionalData: String?
    public let optionalData2: String?

    public init?(mrzString: String, isOCRCorrectionEnabled: Bool) {
        self.init(mrzLines: mrzString.components(separatedBy: "\n"), isOCRCorrectionEnabled: isOCRCorrectionEnabled)
    }

    public init?(
        mrzLines: [String],
        isOCRCorrectionEnabled: Bool
    ) {
        @Dependency(\.mrzCodeCreator) var mrzCodeCreator
        guard let code = mrzCodeCreator.create(mrzLines: mrzLines, isOCRCorrectionEnabled: isOCRCorrectionEnabled) else {
            return nil
        }

        self.init(
            mrzKey: code.mrzKey,
            format: code.format,
            documentType: code.documentType,
            documentSubtype: code.documentSubtype,
            issuingCountry: code.issuingCountry,
            name: code.name,
            documentNumber: code.documentNumber,
            nationalityCountryCode: code.nationalityCountryCode,
            birthdate: code.birthdate,
            sex: code.sex,
            expiryDate: code.expiryDate,
            optionalData: code.optionalData,
            optionalData2: code.optionalData2
        )
    }

    public init(
        mrzKey: String,
        format: MRZCode.Format,
        documentType: DocumentType,
        documentSubtype: DocumentSubtype?,
        issuingCountry: Country,
        name: Name,
        documentNumber: String,
        nationalityCountryCode: String,
        birthdate: Date,
        sex: Sex,
        expiryDate: Date?,
        optionalData: String?,
        optionalData2: String?
    ) {
        self.mrzKey = mrzKey
        self.format = format
        self.documentType = documentType
        self.documentSubtype = documentSubtype
        self.issuingCountry = issuingCountry
        self.name = name
        self.documentNumber = documentNumber
        self.nationalityCountryCode = nationalityCountryCode
        self.birthdate = birthdate
        self.sex = sex
        self.expiryDate = expiryDate
        self.optionalData = optionalData
        self.optionalData2 = optionalData2
    }
}
