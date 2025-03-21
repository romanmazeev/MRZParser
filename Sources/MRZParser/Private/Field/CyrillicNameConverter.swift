//
//  CyrillicNameConverter.swift
//  MRZParser
//
//  Created by Roman Mazeev on 21/02/2025.
//

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct CyrillicNameConverter: Sendable {
    var convert: @Sendable (_ name: String, _ isOCRCorrectionEnabled: Bool) -> String = { _, _  in "" }
}

extension CyrillicNameConverter: DependencyKey {
    static var liveValue: Self {
        return .init { name, isOCRCorrectionEnabled in
            let convert: (String) -> String = {
                $0
                    .replace("A", with: "А")
                    .replace("B", with: "Б")
                    .replace("V", with: "В")
                    .replace("G", with: "Г")
                    .replace("D", with: "Д")
                    .replace("E", with: "Е")
                    .replace("2", with: "Ё")
                    .replace("J", with: "Ж")
                    .replace("Z", with: "З")
                    .replace("I", with: "И")
                    .replace("Q", with: "Й")
                    .replace("K", with: "К")
                    .replace("L", with: "Л")
                    .replace("M", with: "М")
                    .replace("N", with: "Н")
                    .replace("O", with: "О")
                    .replace("P", with: "П")
                    .replace("R", with: "Р")
                    .replace("S", with: "С")
                    .replace("T", with: "Т")
                    .replace("U", with: "У")
                    .replace("F", with: "Ф")
                    .replace("H", with: "Х")
                    .replace("C", with: "Ц")
                    .replace("3", with: "Ч")
                    .replace("4", with: "Ш")
                    .replace("W", with: "Щ")
                    .replace("X", with: "Ъ")
                    .replace("Y", with: "Ы")
                    .replace("9", with: "Ь")
                    .replace("6", with: "Э")
                    .replace("7", with: "Ю")
                    .replace("8", with: "Я")
            }

            // Convert to cyrilic
            let convertedName = convert(name)

            if isOCRCorrectionEnabled {
                // Correct digits to english letters
                @Dependency(\.ocrCorrector) var ocrCorrector
                let correctedName = ocrCorrector.correct(string: convertedName, contentType: .letters)
                // Correct english letters to cyrilic
                return convert(correctedName)
            } else {
                return convertedName
            }
        }
    }
}

extension DependencyValues {
    var cyrillicNameConverter: CyrillicNameConverter {
        get { self[CyrillicNameConverter.self] }
        set { self[CyrillicNameConverter.self] = newValue }
    }
}

#if DEBUG
extension CyrillicNameConverter: TestDependencyKey {
    static let testValue = Self()
}
#endif
