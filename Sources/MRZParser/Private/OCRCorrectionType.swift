//
//  OCRCorrectionType.swift
//  MRZParser
//
//  Created by Roman Mazeev on 20/01/2025.
//

import Foundation

enum OCRCorrectionType {
    case digits
    case letters
    case sex

    var characterSet: CharacterSet {
        switch self {
        case .digits:
            .decimalDigits
        case .letters, .sex:
            .letters
        }
    }

    func replace(_ string: String) -> String {
        switch self {
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
        }
    }
}
