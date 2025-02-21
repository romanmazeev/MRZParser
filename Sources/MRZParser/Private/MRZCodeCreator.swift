//
//  MRZCodeCreator.swift
//  MRZParser
//
//  Created by Roman Mazeev on 17/02/2025.
//

import Dependencies
import DependenciesMacros

@DependencyClient
struct MRZCodeCreator: Sendable {
    var create: @Sendable (_ mrzLines: [String], _ isOCRCorrectionEnabled: Bool) -> MRZCode?
}

extension MRZCodeCreator: DependencyKey {
    static var liveValue: Self {
        // MARK: - MRZ-Format detection

        @Sendable
        func createMRZFormat(from mrzLines: [String]) -> MRZCode.Format? {
            guard let firstLine = mrzLines.first else { return nil }

            /// MRV-B and MRV-A types
            let isVisaDocument = firstLine.first == MRZCode.DocumentType.visa.identifier
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
            finalCheckDigit: Int,
            isOCRCorrectionEnabled: Bool
        ) -> [Field<String>]? {
            let fieldsToValidate = LockIsolated(fieldsToValidate)

            @Dependency(\.validator) var validator
            if !validator.isCompositionValid(validatedFields: fieldsToValidate.value, finalCheckDigit: finalCheckDigit) {
                if isOCRCorrectionEnabled {
                    let fieldsToBruteForce = fieldsToValidate.value.filter { $0.type.contentType == .mixed }
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
                guard let format = createMRZFormat(from: mrzLines) else { return nil }

                @Dependency(\.fieldCreator) var fieldCreator

                // MARK: Required fields

                guard
                    var documentTypeField = fieldCreator.createStringField(
                        lines: mrzLines,
                        format: format,
                        type: .documentType,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ),
                    var countryCodeField = fieldCreator.createStringField(
                        lines: mrzLines,
                        format: format,
                        type: .countryCode,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ),
                    var documentNumberField = fieldCreator.createStringField(
                        lines: mrzLines,
                        format: format,
                        type: .documentNumber,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ),
                    let birthdateField = fieldCreator.createDateField(
                        lines: mrzLines,
                        format: format,
                        dateFieldType: .birth,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ),
                    let expiryDateField = fieldCreator.createDateField(
                        lines: mrzLines,
                        format: format,
                        dateFieldType: .expiry,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ),
                    var sexField = fieldCreator.createStringField(
                        lines: mrzLines,
                        format: format,
                        type: .sex,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ),
                    var nationalityField = fieldCreator.createStringField(
                        lines: mrzLines,
                        format: format,
                        type: .nationality,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ),
                    let namesField = fieldCreator.createNamesField(
                        lines: mrzLines,
                        format: format,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    )
                else {
                    return nil
                }

                // MARK: Optional fields

                var optionalDataField =  fieldCreator.createStringField(
                    lines: mrzLines,
                    format: format,
                    type: .optionalData(.one),
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                )

                var optionalData2Field =  fieldCreator.createStringField(
                    lines: mrzLines,
                    format: format,
                    type: .optionalData(.two),
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                )

                let finalCheckDigitField =  fieldCreator.createIntField(
                    lines: mrzLines,
                    format: format,
                    isOCRCorrectionEnabled: isOCRCorrectionEnabled
                )

                if let finalCheckDigitField {
                    guard let correctedFields = validateAndCorrectIfNeeded(
                        fieldsToValidate: FieldType.finalValidateFields(mrzFormat: format).compactMap {
                            switch $0 {
                            case .documentType:
                                documentTypeField
                            case .countryCode:
                                countryCodeField
                            case .documentNumber:
                                documentNumberField
                            case .date(.birth):
                                birthdateField
                            case .date(.expiry):
                                expiryDateField
                            case .sex:
                                sexField
                            case .nationality:
                                nationalityField
                            case .names:
                                namesField
                            case .optionalData(.one):
                                optionalDataField
                            case .optionalData(.two):
                                optionalData2Field
                            case .finalCheckDigit:
                                finalCheckDigitField
                            }
                        },
                        finalCheckDigit: finalCheckDigitField.value,
                        isOCRCorrectionEnabled: isOCRCorrectionEnabled
                    ) else {
                        return nil
                    }

                    correctedFields.forEach { field in
                        switch field.type {
                        case .documentType:
                            documentTypeField = field
                        case .countryCode:
                            countryCodeField = field
                        case .documentNumber:
                            documentNumberField = field
                        case .sex:
                            sexField = field
                        case .nationality:
                            nationalityField = field
                        case .optionalData(.one):
                            optionalDataField = field
                        case .optionalData(.two):
                            optionalData2Field = field
                        default:
                            assertionFailure("Unexpected field type")
                        }
                    }
                }

                let mrzKey = documentNumberField.value + (documentNumberField.checkDigit.map { String($0) } ?? "")
                    + birthdateField.rawValue + (birthdateField.checkDigit.map { String($0) } ?? "")
                    + expiryDateField.rawValue + (expiryDateField.checkDigit.map { String($0) } ?? "")

                let documentType = MRZCode.DocumentType.allCases.first {
                    $0.identifier == documentTypeField.value.first
                } ?? .undefined
                let documentTypeAdditional = documentTypeField.value.count == 2
                    ? documentTypeField.value.last
                    : nil
                let sex = MRZCode.Sex.allCases.first {
                    $0.identifier.contains(sexField.value)
                } ?? .unspecified

                return .init(
                    mrzKey: mrzKey,
                    format: format,
                    documentType: documentType,
                    documentTypeAdditional: documentTypeAdditional,
                    countryCode: countryCodeField.value,
                    names: namesField.value,
                    documentNumber: documentNumberField.value,
                    nationalityCountryCode: nationalityField.value,
                    birthdate: birthdateField.value,
                    sex: sex,
                    expiryDate: expiryDateField.value,
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
