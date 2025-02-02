//
//  MRZCode.swift
//
//
//  Created by Roman Mazeev on 20.07.2021.
//

import Foundation

struct MRZCode {
    let format: MRZFormat
    let documentTypeField: String
    let countryCodeField: String
    let documentNumberField: ValidatedField<String>
    let birthdateField: ValidatedField<Date>
    let sexField: String
    let expiryDateField: ValidatedField<Date>
    let nationalityField: String
    var optionalDataField: ValidatedField<String>?
    var optionalData2Field: ValidatedField<String>?
    let namesField: NamesField
    let finalCheckDigit: Int?

    private let fieldFactory: MRZFieldFactory

    private var basicValidatedFields: [ValidatedFieldProtocol] {
        [
            documentNumberField,
            birthdateField,
            expiryDateField
        ]
    }

    private var optionalValidatedFields: [ValidatedFieldProtocol] {
        var fields: [ValidatedFieldProtocol] = []

        if let optionalDataField {
            fields.append(optionalDataField)
        }

        if let optionalData2Field {
            fields.append(optionalData2Field)
        }

        return fields
    }

    var isCompositionValid: Bool {
        isCompositionValid(optionalValidatedFields: optionalValidatedFields)
    }

    var allFieldsAreValid: Bool {
        (basicValidatedFields + optionalValidatedFields).allSatisfy(\.isValid)
    }

    private func isCompositionValid(optionalValidatedFields: [ValidatedFieldProtocol]) -> Bool {
        let validatedFields = {
            if format == .td1 {
                var result: [ValidatedFieldProtocol] = [documentNumberField]
                if let firstOptionalValidatedField = optionalValidatedFields.first {
                    result.append(firstOptionalValidatedField)
                }

                result += [birthdateField, expiryDateField]

                if optionalValidatedFields.count > 0 {
                    result.append(optionalValidatedFields[1])
                }
                return result
            } else {
                return basicValidatedFields + optionalValidatedFields
            }
        }()

        let compositedValue = validatedFields.reduce("", { $0 + $1.rawValue + ($1.checkDigit.map { String($0) } ?? "") })
        return Self.isValueValid(compositedValue, checkDigit: finalCheckDigit)
    }

    mutating func bruteForceCorrectOptionalDataIfNeeded() -> Bool {
        let matchingStrings = findMatchingString(
            optionalValidatedFields.map(\.rawValue),
            isCorrectCombination: { combination in
                var fields: [ValidatedField<String>] = []

                if let firstString = combination.first,
                   let firstValue = fieldFactory.text(from: firstString) {
                    fields.append(.init(
                        value: firstValue,
                        rawValue: firstString,
                        checkDigit: optionalDataField?.checkDigit
                    ))

                    if combination.count > 1 {
                        let secondString = combination[1]
                        if let secondValue = fieldFactory.text(from: secondString) {
                            fields.append(.init(
                                value: secondValue,
                                rawValue: secondString,
                                checkDigit: optionalData2Field?.checkDigit
                            ))
                        }
                    }
                }

                return isCompositionValid(optionalValidatedFields: fields)
            }
        )

        if let matchingStrings,
           let firstMatchingString = matchingStrings.first,
           let firstValue = fieldFactory.text(from: firstMatchingString) {
            optionalDataField = .init(
                value: firstValue,
                rawValue: firstMatchingString,
                checkDigit: optionalDataField?.checkDigit
            )

            if matchingStrings.count > 1 {
                let secondMatchingString = matchingStrings[1]
                if let secondValue = fieldFactory.text(from: secondMatchingString) {
                    optionalData2Field = .init(
                        value: secondValue,
                        rawValue: secondMatchingString,
                        checkDigit: optionalData2Field?.checkDigit
                    )
                }
            }

            return true
        } else {
            return false
        }
    }

    func findMatchingString(_ strings: [String], isCorrectCombination: ([String]) -> Bool) -> [String]? {
        var result: [String]?
        var stringsArray = strings.map { Array($0) }

        let getTransformedCharacters: (Character) -> [Character] = {
            let digitsReplacedCharacter =  Character(OCRCorrectionType.digits.replace(String($0)))
            let lettersReplacedCharacter =  Character(OCRCorrectionType.letters.replace(String($0)))
            return [$0, digitsReplacedCharacter, lettersReplacedCharacter]
        }

        func dfs(index: Int) -> Bool {
            if index == stringsArray.count {
                // If we've modified all strings, check the combination
                let currentCombination = stringsArray.map { String($0) }
                if isCorrectCombination(currentCombination) {
                    result = currentCombination
                    return true
                }
                return false
            }

            // Iterate over every character position in the current string
            for i in 0..<stringsArray[index].count {
                let originalChar = stringsArray[index][i]

                // Generate replacements for the current character
                let replacements = getTransformedCharacters(originalChar)

                // Try each replacement character
                for char in replacements {
                    stringsArray[index][i] = char
                    if dfs(index: index + 1) { // Recurse for the next string
                        return true
                    }
                }

                // Restore the original character before moving to the next position
                stringsArray[index][i] = originalChar
            }

            return false
        }

        if dfs(index: 0) {
            return result
        } else {
            return nil
        }
    }

    init?(
        from mrzLines: [String],
        format: MRZFormat,
        isOCRCorrectionEnabled: Bool
    ) {
        let (firstLine, secondLine) = (mrzLines[0], mrzLines[1])
        let fieldFactory = MRZFieldFactory(isOCRCorrectionEnabled: isOCRCorrectionEnabled)

        guard let documentTypeField = fieldFactory.createStringField(from: firstLine, at: 0, length: 2, ocrCorrectionType: .letters),
              let countryCodeField = fieldFactory.createStringField(from: firstLine, at: 2, length: 3, ocrCorrectionType: .letters) else {
            return nil
        }

        switch format {
        case .td1:
            let thirdLine = mrzLines[2]
            guard
                let documentNumberField = fieldFactory.createStringValidatedField(
                    from: firstLine,
                    at: 5,
                    length: 9
                ),
                let birthdateField = fieldFactory.createDateValidatedField(
                    from: secondLine,
                    at: 0,
                    length: 6,
                    fieldType: .birthdate
                ),
                let sexField = fieldFactory.createStringField(from: secondLine, at: 7, length: 1, ocrCorrectionType: .sex),
                let expiryDateField = fieldFactory.createDateValidatedField(
                    from: secondLine,
                    at: 8,
                    length: 6,
                    fieldType: .expiryDate
                ),
                let nationalityField = fieldFactory.createStringField(from: secondLine, at: 15, length: 3, ocrCorrectionType: .letters),
                let namesField = fieldFactory.createNamesField(from: thirdLine, at: 0, length: 29) else {
                return nil
            }

            self.documentNumberField = documentNumberField
            self.birthdateField = birthdateField
            self.sexField = sexField
            self.expiryDateField = expiryDateField
            self.nationalityField = nationalityField
            optionalDataField = fieldFactory.createStringValidatedField(
                from: firstLine,
                at: 15,
                length: 15,
                checkDigitFollows: false
            )
            optionalData2Field = fieldFactory.createStringValidatedField(
                from: secondLine,
                at: 18,
                length: 11,
                checkDigitFollows: false
            )
            finalCheckDigit = fieldFactory.createIntField(from: secondLine, at: 29, length: 1)
            self.namesField = namesField
        case .td2, .td3:
            /// MRV-B and MRV-A types
            let isVisaDocument = firstLine.first == MRZResult.DocumentType.visa.identifier
            guard let documentNumberField = fieldFactory.createStringValidatedField(from: secondLine, at: 0, length: 9),
                  let birthdateField = fieldFactory.createDateValidatedField(
                    from: secondLine,
                    at: 13,
                    length: 6,
                    fieldType: .birthdate
                  ),
                  let sexField = fieldFactory.createStringField(from: secondLine, at: 20, length: 1, ocrCorrectionType: .sex),
                  let expiryDateField = fieldFactory.createDateValidatedField(
                      from: secondLine, at: 21, length: 6, fieldType: .expiryDate
                  ),
                  let nationalityField = fieldFactory.createStringField(from: secondLine, at: 10, length: 3, ocrCorrectionType: .letters) else {
                return nil
            }
            self.documentNumberField = documentNumberField
            self.birthdateField = birthdateField
            self.sexField = sexField
            self.expiryDateField = expiryDateField
            self.nationalityField = nationalityField

            if format == .td2 {
                guard let namesField = fieldFactory.createNamesField(from: firstLine, at: 5, length: 31) else {
                    return nil
                }
                optionalDataField = fieldFactory.createStringValidatedField(
                    from: secondLine,
                    at: 28,
                    length: isVisaDocument ? 8 : 7,
                    checkDigitFollows: false
                )
                optionalData2Field = nil
                self.namesField = namesField
                finalCheckDigit = isVisaDocument ? nil : fieldFactory.createIntField(
                    from: secondLine, at: 35, length: 1
                )
            } else {
                guard let namesField = fieldFactory.createNamesField(from: firstLine, at: 5, length: 39) else {
                    return nil
                }
                optionalDataField = if isVisaDocument {
                    fieldFactory.createStringValidatedField(
                        from: secondLine,
                        at: 28,
                        length: 16,
                        checkDigitFollows: false
                    )
                } else {
                    fieldFactory.createStringValidatedField(
                        from: secondLine, at: 28, length: 14
                    )
                }
                optionalData2Field = nil
                self.namesField = namesField
                finalCheckDigit = isVisaDocument ? nil : fieldFactory.createIntField(
                    from: secondLine,
                    at: 43,
                    length: 1
                )
            }
        }

        self.documentTypeField = documentTypeField
        self.countryCodeField = countryCodeField
        self.format = format
        self.fieldFactory = fieldFactory
    }

    static func isValueValid(_ rawValue: String, checkDigit: Int?) -> Bool {
        guard let checkDigit else { return true }

        return getCheckDigit(for: rawValue) == checkDigit
    }

    private static func getCheckDigit(for value: String) -> Int? {
        var sum: Int = 0
        for (index, character) in value.enumerated() {
            guard let number = getNumber(for: character) else { return nil }
            let weights = [7, 3, 1]
            sum += number * weights[index % 3]
        }
        return sum % 10
    }

    // <  A   B   C   D   E   F   G   H   I   J   K   L   M   N   O   P   Q   R   S   T   U   V   W   X   Y   Z
    // 0  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35
    private static func getNumber(for character: Character) -> Int? {
        guard let unicodeScalar = character.unicodeScalars.first else { return nil }

        let number: Int
        if CharacterSet.uppercaseLetters.contains(unicodeScalar) {
            number = Int(10 + unicodeScalar.value) - 65
        } else if CharacterSet.decimalDigits.contains(unicodeScalar), let digit = character.wholeNumberValue {
            number = digit
        } else if character == "<" {
            number = 0
        } else {
            return nil
        }

        return number
    }
}
