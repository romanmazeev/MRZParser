//
//  MRZCodeTests.swift
//  MRZParser
//
//  Created by Roman Mazeev on 17/02/2025.
//

import CustomDump
import Dependencies
import XCTest
@testable import MRZParser

final class MRZCodeTests: XCTestCase {
    private enum Event: Equatable, Sendable {
        case create(_ lines: [String], _ isOCRCorrectionEnabled: Bool)
    }

    func testParsing() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.mrzCodeCreator.create = { @Sendable lines, isOCRCorrectionEnabled in
                events.withValue { $0.append(.create(lines, isOCRCorrectionEnabled)) }
                return .mock
            }
        } operation: {
            XCTAssertEqual(MRZCode(mrzString: "1\n2\n3", isOCRCorrectionEnabled: false), .mock)

            expectNoDifference(
                events.value,
                [
                    .create(["1", "2", "3"], false)
                ]
            )
        }
    }

    func testParsingFailed() {
        let events = LockIsolated([Event]())

        withDependencies {
            $0.mrzCodeCreator.create = { @Sendable lines, isOCRCorrectionEnabled in
                events.withValue { $0.append(.create(lines, isOCRCorrectionEnabled)) }
                return nil
            }
        } operation: {
            XCTAssertNil(MRZCode(mrzString: "1\n2\n3", isOCRCorrectionEnabled: true))

            expectNoDifference(
                events.value,
                [
                    .create(["1", "2", "3"], true)
                ]
            )
        }
    }
}

private extension MRZCode {
    static var mock: Self {
        .init(
            mrzKey: "L898902C3674081221204159",
            format: .td3(isVisaDocument: false),
            documentType: .other("K"),
            documentTypeAdditional: nil,
            country: .other("UTO"),
            names: .init(surnames: "ERIKSSON", givenNames: "ANNA MARIA"),
            documentNumber: "L898902C3",
            nationalityCountryCode: "UTO",
            birthdate: .init(timeIntervalSince1970: 0),
            sex: .female,
            expiryDate: .init(timeIntervalSince1970: 0),
            optionalData: "ZE184226B",
            optionalData2: nil
        )
    }
}
