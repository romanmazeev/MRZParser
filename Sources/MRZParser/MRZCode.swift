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

    public enum DocumentType: CaseIterable, Sendable {
        case visa
        case passport
        case id
        case undefined
    }

    public enum DocumentTypeAdditional: CaseIterable, Sendable {
        case national
        case diplomatic
    }

    public enum Sex: CaseIterable, Sendable {
        case male
        case female
        case unspecified
    }

    public struct Names: Sendable, Hashable {
        public let surnames: String
        public let givenNames: String?

        public init(surnames: String, givenNames: String?) {
            self.surnames = surnames
            self.givenNames = givenNames
        }
    }

    public let mrzKey: String
    public let format: Format
    public let documentType: DocumentType
    public let documentTypeAdditional: DocumentTypeAdditional?
    public let countryCode: String
    public let names: Names
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
            documentTypeAdditional: code.documentTypeAdditional,
            countryCode: code.countryCode,
            names: code.names,
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
        documentTypeAdditional: DocumentTypeAdditional?,
        countryCode: String,
        names: Names,
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
        self.documentTypeAdditional = documentTypeAdditional
        self.countryCode = countryCode
        self.names = names
        self.documentNumber = documentNumber
        self.nationalityCountryCode = nationalityCountryCode
        self.birthdate = birthdate
        self.sex = sex
        self.expiryDate = expiryDate
        self.optionalData = optionalData
        self.optionalData2 = optionalData2
    }
}
