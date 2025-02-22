//
//  CyrillicNameConverterTests.swift
//  MRZParser
//
//  Created by Roman Mazeev on 22/02/2025.
//

import CustomDump
import Dependencies
@testable import MRZParser
import XCTest

final class CyrillicNameConverterTests: XCTestCase {
    private enum Event: Equatable, Sendable {
        case correct(String, FieldType.ContentType)
    }

    func testConvert() {
        let events = LockIsolated([Event]())
        let correctedValue = "test"

        withDependencies {
            $0.ocrCorrector.correct = { @Sendable string, correctionType in
                events.withValue { $0.append(.correct(string, correctionType)) }
                return correctedValue
            }
        } operation: {
            XCTAssertEqual(
                CyrillicNameConverter.liveValue.convert("ABVGDE2JZIQKLMNOPRSTUFHC34WXY96785"),
                correctedValue
            )

            expectNoDifference(
                events.value,
                [
                    .correct(
                        "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ5",
                        .letters
                    )
                ]
            )
        }
    }
}
