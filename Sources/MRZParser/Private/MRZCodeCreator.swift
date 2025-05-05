//
//  MRZCodeCreator.swift
//  MRZParser
//
//  Created by Roman Mazeev on 17/02/2025.
//

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct MRZCodeCreator: Sendable {
    var create: @Sendable (_ mrzLines: [String], _ isOCRCorrectionEnabled: Bool) -> MRZCode?
}

extension MRZCodeCreator: DependencyKey {
    static var liveValue: Self {
        // MARK: - MRZ-Format detection

        @Sendable
        func createMRZFormat(from mrzLines: [String]) -> MRZCode.Format? {
            guard let firstLine = mrzLines.first, let firstCharacter = firstLine.first else { return nil }

            /// MRV-B and MRV-A types
            let isVisaDocument = MRZCode.DocumentType(identifier: firstCharacter) == .visa
            let td2Format = MRZCode.Format.td2(isVisaDocument: isVisaDocument)
            let td3Format = MRZCode.Format.td3(isVisaDocument: isVisaDocument)

            switch mrzLines.count {
            case td2Format.linesCount, td3Format.linesCount:
                return [td2Format, td3Format].first(where: { $0.lineLength == uniformedLineLength(for: mrzLines) })
            case MRZCode.Format.td1.linesCount:
                return (uniformedLineLength(for: mrzLines) == MRZCode.Format.td1.lineLength) ? .td1 : nil
            default:
                return nil
            }
        }

        @Sendable
        func uniformedLineLength(for mrzLines: [String]) -> Int? {
            let lineLength = mrzLines[0].count
            guard mrzLines.allSatisfy({ $0.count == lineLength }) else { return nil }

            return lineLength
        }

        // MARK: - Initialisation

        @Sendable
        func validateAndCorrectIfNeeded(
            fieldsToValidate: [any FieldProtocol],
            isRussianNationalPassport: Bool,
            finalCheckDigit: Int,
            isOCRCorrectionEnabled: Bool
        ) -> [Field<String>]? {
            let fieldsToValidate = LockIsolated(fieldsToValidate)

            @Dependency(\.validator) var validator
            if !validator.isCompositionValid(validatedFields: fieldsToValidate.value, finalCheckDigit: finalCheckDigit) {
                if isOCRCorrectionEnabled {
                    let fieldsToBruteForce = fieldsToValidate.value.filter { $0.type.contentType(isRussianNationalPassport: isRussianNationalPassport) == .mixed }
                    // TODO: Do not bruteforce check digit
                    @Dependency(\.ocrCorrector) var ocrCorrector
                    guard let updatedFields = ocrCorrector.findMatchingStrings(strings: fieldsToBruteForce.map(\.rawValue), isCorrectCombination: { combination in
                        combination.enumerated().forEach { index, element in
                            guard let value = element.fieldValue else {
                                assertionFailure("Can not be nil")
                                return
                            }

                            let field = Field<String>(
                                value: value,
                                rawValue: element,
                                checkDigit: fieldsToBruteForce[index].checkDigit,
                                type: fieldsToBruteForce[index].type
                            )

                            guard let index = fieldsToValidate.value.firstIndex(where: { $0.type == field.type }) else {
                                assertionFailure("Can not be nil")
                                return
                            }

                            fieldsToValidate.withValue { $0[index] = field }
                        }

                        return validator.isCompositionValid(validatedFields: fieldsToValidate.value, finalCheckDigit: finalCheckDigit)
                    }) else {
                        return nil
                    }

                    var result: [Field<String>] = []
                    fieldsToBruteForce.enumerated().forEach {
                        guard let value = updatedFields[$0.offset].fieldValue else {
                            assertionFailure("Can not be nil")
                            return
                        }

                        result.append(.init(
                            value: value,
                            rawValue: updatedFields[$0.offset],
                            checkDigit: $0.element.checkDigit,
                            type: $0.element.type
                        ))
                    }

                    return result
                } else {
                    return nil
                }
            } else {
                return [] // No corrections needed
            }
        }

        return .init(
            create: { mrzLines, isOCRCorrectionEnabled in
                // MARK: Dutch single-line fallback (ISO 18013-1, e.g. D1NLD...)
                if mrzLines.count == 1, let line = mrzLines.first, line.starts(with: "D1NLD"), line.count >= 30 {
                    func slice(_ str: String, _ start: Int, _ end: Int) -> String {
                        let startIdx = str.index(str.startIndex, offsetBy: start)
                        let endIdx = str.index(str.startIndex, offsetBy: end)
                        return String(str[startIdx..<endIdx])
                    }

                    let documentNumber = slice(line, 5, 14)
                    let birthdateStr = slice(line, 14, 20)
                    let expiryDateStr = slice(line, 20, 26)

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyMMdd"
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    guard
                        let birthdate = dateFormatter.date(from: birthdateStr),
                        let expiryDate = dateFormatter.date(from: expiryDateStr)
                    else {
                        return nil
                    }

                    return MRZCode(
                        mrzKey: documentNumber + birthdateStr + expiryDateStr,
                        format: .td1, // TODO: Consider defining `dutchSingleLine` format in future refactor
                        documentType: MRZCode.DocumentType(identifier: "D"),
                        documentTypeAdditional: nil,
                        country: MRZCode.Country(identifier: "NLD"),
                        names: MRZCode.Names(surnames: "<<", givenNames: nil),
                        documentNumber: documentNumber,
                        nationalityCountryCode: "NLD",
                        birthdate: birthdate,
                        sex: .unspecified,
                        expiryDate: expiryDate,
                        optionalData: nil,
                        optionalData2: nil
                    )
                }

                guard let format = createMRZFormat(from: mrzLines) else { return nil }

                @Dependency(\.fieldCreator) var fieldCreator

                guard
                    let documentType = fieldCreator.createCharacterField(
                        lines: mrzLines,
                        format: format,
                        type: .documentType,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ).map({ MRZCode.DocumentType(identifier: $0.value) }),
                    let issuingCountry = fieldCreator.createStringField(
                        lines: mrzLines,
                        format: format,
                        type: .issuingCountryCode,
                        isRussianNationalPassport: false,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ).map({ MRZCode.Country(identifier: $0.value) }),
                    let birthdateField = fieldCreator.createDateField(
                        lines: mrzLines,
                        format: format,
                        dateFieldType: .birth,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ),
                    let sexField = fieldCreator.createCharacterField(
                        lines: mrzLines,
                        format: format,
                        type: .sex,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    )
                else {
                    return nil
                }

                let documentSubtype = fieldCreator.createCharacterField(
                    lines: mrzLines,
                    format: format,
                    type: .documentSubtype,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                ).map { MRZCode.DocumentSubtype(identifier: $0.value) }

                let isRussianNationalPassport = documentType == .passport && documentSubtype == .national && issuingCountry == .russia

                var optionalDataField = fieldCreator.createStringField(
                    lines: mrzLines,
                    format: format,
                    type: .optionalData(.one),
                    isRussianNationalPassport: isRussianNationalPassport,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                )

                guard
                    let nameField = fieldCreator.createNameField(
                        lines: mrzLines,
                        format: format,
                        isRussianNationalPassport: isRussianNationalPassport,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ),
                    var documentNumberField = fieldCreator.createDocumentNumberField(
                        lines: mrzLines,
                        format: format,
                        russianNationalPassportHiddenCharacter: isRussianNationalPassport ? optionalDataField?.value.first : nil,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ),
                    let nationalityField = fieldCreator.createStringField(
                        lines: mrzLines,
                        format: format,
                        type: .nationalityCountryCode,
                        isRussianNationalPassport: isRussianNationalPassport,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    )
                else {
                    return nil
                }

                let expiryDateField = fieldCreator.createDateField(
                    lines: mrzLines,
                    format: format,
                    dateFieldType: .expiry,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                )

                var optionalData2Field = fieldCreator.createStringField(
                    lines: mrzLines,
                    format: format,
                    type: .optionalData(.two),
                    isRussianNationalPassport: isRussianNationalPassport,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                )

                let finalCheckDigitField = fieldCreator.createFinalCheckDigitField(
                    lines: mrzLines,
                    format: format,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                )

                if let finalCheckDigitField {
                    guard let correctedFields = validateAndCorrectIfNeeded(
                        fieldsToValidate: FieldType.validateFinalCheckDigitFields(mrzFormat: format).compactMap {
                            switch $0 {
                            case .documentNumber:
                                documentNumberField
                            case .date(.birth):
                                birthdateField
                            case .date(.expiry):
                                expiryDateField ?? .init(value: .distantFuture, rawValue: "<<<<<<", checkDigit: 0, type: .date(.expiry))
                            case .optionalData(.one):
                                optionalDataField
                            case .optionalData(.two):
                                optionalData2Field
                            default:
                                fatalError("Unexpected field type")
                            }
                        },
                        isRussianNationalPassport: isRussianNationalPassport,
                        finalCheckDigit: finalCheckDigitField.value,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ) else {
                        return nil
                    }

                    correctedFields.forEach { field in
                        switch field.type {
                        case .documentNumber:
                            documentNumberField = field
                        case .optionalData(.one):
                            optionalDataField = field
                        case .optionalData(.two):
                            optionalData2Field = field
                        default:
                            assertionFailure("Unexpected field type")
                        }
                    }
                }

                let mrzKey = {
                    var mrzKeyFields: [any FieldProtocol] = [documentNumberField, birthdateField]
                    if let expiryDateField = expiryDateField {
                        mrzKeyFields.append(expiryDateField)
                    }

                    return mrzKeyFields.reduce(into: "") { result, field in
                        let rawValue = field.rawValue
                        let checkDigit = field.checkDigit.map { String($0) } ?? ""
                        result += rawValue + checkDigit
                    }
                }()

                return .init(
                    mrzKey: mrzKey,
                    format: format,
                    documentType: documentType,
                    documentSubtype: documentSubtype,
                    issuingCountry: issuingCountry,
                    name: nameField.value,
                    documentNumber: documentNumberField.value,
                    nationalityCountryCode: nationalityField.value,
                    birthdate: birthdateField.value,
                    sex: .init(identifier: sexField.value),
                    expiryDate: expiryDateField?.value,
                    optionalData: optionalDataField?.value,
                    optionalData2: optionalData2Field?.value
                )
            }
        )
    }
}

extension DependencyValues {
    var mrzCodeCreator: MRZCodeCreator {
        get { self[MRZCodeCreator.self] }
        set { self[MRZCodeCreator.self] = newValue }
    }
}

#if DEBUG
extension MRZCodeCreator: TestDependencyKey {
    static let testValue = Self()
}
#endif
