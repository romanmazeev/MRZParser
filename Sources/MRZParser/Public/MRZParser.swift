//
//  MRZParser.swift
//
//
//  Created by Roman Mazeev on 15.06.2021.
//

public struct MRZParser {
    private let formatter: MRZFieldFormatter

    public init(isOCRCorrectionEnabled: Bool) {
        formatter = MRZFieldFormatter(isOCRCorrectionEnabled: isOCRCorrectionEnabled)
    }

    init(formatter: MRZFieldFormatter) {
        self.formatter = formatter
    }

    // MARK: Parsing
    public func parse(mrzLines: [String]) -> MRZResult? {
        guard let format = mrzFormat(from: mrzLines) else { return nil }

        let mrzCode: MRZCode = MRZCodeFactory().create(
            from: mrzLines,
            format: format,
            formatter: formatter
        )

        guard mrzCode.isValid else { return nil }

        let documentType = MRZResult.DocumentType.allCases.first {
            $0.identifier == mrzCode.documentTypeField.value.first
        } ?? .undefined
        let documentTypeAdditional = mrzCode.documentTypeField.value.count == 2
            ? mrzCode.documentTypeField.value.last
            : nil
        let sex = MRZResult.Sex.allCases.first {
            $0.identifier.contains(mrzCode.sexField.value)
        } ?? .unspecified
        let documentNumber = makeDocumentNumberString(from: mrzCode)

        return .init(
            format: format,
            documentType: documentType,
            documentTypeAdditional: documentTypeAdditional,
            countryCode: mrzCode.countryCodeField.value,
            surnames: mrzCode.namesField.surnames,
            givenNames: mrzCode.namesField.givenNames,
            documentNumber: documentNumber,
            nationalityCountryCode: mrzCode.nationalityField.value,
            birthdate: mrzCode.birthdateField.value,
            sex: sex,
            expiryDate: mrzCode.expiryDateField.value,
            optionalData: mrzCode.optionalDataField.value,
            optionalData2: mrzCode.optionalData2Field?.value
        )
    }

    public func parse(mrzString: String) -> MRZResult? {
        return parse(mrzLines: mrzString.components(separatedBy: "\n"))
    }

    // MARK: MRZ-Format detection
    private func mrzFormat(from mrzLines: [String]) -> MRZFormat? {
        switch mrzLines.count {
        case MRZFormat.td2.linesCount,  MRZFormat.td3.linesCount:
            return [.td2, .td3].first(where: { $0.lineLength == uniformedLineLength(for: mrzLines) })
        case MRZFormat.td1.linesCount:
            return (uniformedLineLength(for: mrzLines) == MRZFormat.td1.lineLength) ? .td1 : nil
        default:
            return nil
        }
    }

    private func uniformedLineLength(for mrzLines: [String]) -> Int? {
        guard let lineLength = mrzLines.first?.count,
              !mrzLines.contains(where: { $0.count != lineLength }) else { return nil }
        return lineLength
    }

    private func makeDocumentNumberString(from mrzCode: MRZCode) -> String {
        var number = mrzCode.documentNumberField.value

        // Exceptional condition for Russian national passport
        if mrzCode.documentTypeField.value == "PN"
            && mrzCode.countryCodeField.value == "RUS"
            && mrzCode.documentNumberField.value.count == 9,
            let hiddenDigit = mrzCode.optionalDataField.value.first {
            number.insert(hiddenDigit, at: number.index(number.startIndex, offsetBy: 3))
        }

        return number
    }
}
