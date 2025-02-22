//
//  Validator.swift
//  MRZParser
//
//  Created by Roman Mazeev on 17/02/2025.
//

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct Validator: Sendable {
    var isCompositionValid: @Sendable (_ validatedFields: [any FieldProtocol], _ finalCheckDigit: Int) -> Bool = { _, _ in false }
    var isValueValid: @Sendable (_ rawValue: String, _ checkDigit: Int) -> Bool = { _, _ in false }
    var isContentTypeValid: @Sendable (_ value: String, _ contentType: FieldType.ContentType) -> Bool = { _, _ in false }
}

extension Validator: DependencyKey {
    static var liveValue: Self {
        @Sendable
        func isValueValid(_ rawValue: String, checkDigit: Int) -> Bool {
            getCheckDigit(for: rawValue) == checkDigit
        }

        @Sendable
        func getCheckDigit(for value: String) -> Int? {
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
        @Sendable
        func getNumber(for character: Character) -> Int? {
            guard let unicodeScalar = character.unicodeScalars.first else {
                assertionFailure("Character can not be empty")
                return nil
            }

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

        return .init(
            isCompositionValid: { validatedFields, finalCheckDigit in
                let compositedValue = validatedFields.reduce("", { $0 + $1.rawValue + ($1.checkDigit.map { String($0) } ?? "") })
                return isValueValid(compositedValue, checkDigit: finalCheckDigit)
            },
            isValueValid: { rawValue, checkDigit in
                isValueValid(rawValue, checkDigit: checkDigit)
            },
            isContentTypeValid: { value, contentType in
                if let characterSet = contentType.characterSet, !characterSet.isSuperset(of: CharacterSet(charactersIn: value.replace("<", with: ""))) {
                    return false
                } else {
                    return true
                }
            }
        )
    }
}

extension DependencyValues {
    var validator: Validator {
        get { self[Validator.self] }
        set { self[Validator.self] = newValue }
    }
}

#if DEBUG
extension Validator: TestDependencyKey {
    static let testValue = Self()
}
#endif
