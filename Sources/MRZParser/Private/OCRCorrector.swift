//
//  OCRCorrector.swift
//  MRZParser
//
//  Created by Roman Mazeev on 17/02/2025.
//

import Dependencies
import DependenciesMacros

@DependencyClient
struct OCRCorrector: Sendable {
    var correct: @Sendable (_ string: String, _ contentType: FieldType.ContentType) -> String = { _, _ in "" }
    var findMatchingStrings: @Sendable (_ strings: [String], _ isCorrectCombination: @Sendable ([String]) -> Bool) -> [String]?
}

extension OCRCorrector: DependencyKey {
    static var liveValue: Self {
        @Sendable
        func correct(string: String, contentType: FieldType.ContentType) -> String {
            switch contentType {
            case .digits:
                return string
                    .replace("O", with: "0")
                    .replace("Q", with: "0")
                    .replace("U", with: "0")
                    .replace("D", with: "0")
                    .replace("I", with: "1")
                    .replace("Z", with: "2")
                    .replace("B", with: "8")
            case .letters:
                return string
                    .replace("0", with: "O")
                    .replace("1", with: "I")
                    .replace("2", with: "Z")
                    .replace("8", with: "B")
            case .sex:
                return string
                    .replace("P", with: "F")
            case .mixed:
                return string
            }
        }

        return .init(
            correct: { string, contentType in
                correct(string: string, contentType: contentType)
            },
            findMatchingStrings: { strings, isCorrectCombination in
                var result: [String]?
                var stringsArray = strings.map { Array($0) }

                let getTransformedCharacters: (Character) -> [Character] = {
                    let digitsReplacedCharacter = Character(correct(string: String($0), contentType: .digits))
                    let lettersReplacedCharacter = Character(correct(string: String($0), contentType: .letters))
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

                return dfs(index: 0) ? result : nil
            }
        )
    }
}

extension DependencyValues {
    var ocrCorrector: OCRCorrector {
        get { self[OCRCorrector.self] }
        set { self[OCRCorrector.self] = newValue }
    }
}

#if DEBUG
extension OCRCorrector: TestDependencyKey {
    static let testValue = Self()
}
#endif
