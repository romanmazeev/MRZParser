//
//  MRZCodeIntegrationTests.swift
//  MRZParser
//
//  Created by Roman Mazeev on 26/02/2025.
//

import Dependencies
import XCTest
@testable import MRZParser

/// Only for debugging
final class MRZCodeIntegrationTests: XCTestCase {
    func testIntegration() {
        withDependencies {
            $0.mrzCodeCreator = .liveValue
            $0.fieldCreator = .liveValue
            $0.cyrillicNameConverter = .liveValue
            $0.fieldComponentsCreator = .liveValue
            $0.ocrCorrector = .liveValue
            $0.validator = .liveValue
            $0.date.now = .now
        } operation: {
            let result = MRZCode(
                mrzLines: [],
                isOCRCorrectionEnabled: true
            )
            print(result ?? "nil")
        }
    }
}
