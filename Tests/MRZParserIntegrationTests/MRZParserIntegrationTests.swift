//
//  MRZParserTests.swift
//
//
//  Created by Roman Mazeev on 15.06.2021.
//

import XCTest
@testable import MRZParser

final class MRZParserTests: XCTestCase {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT+0:00")
        return formatter
    }()

    func testTD1() throws {
        let mrzString = """
                        I<UTOD231458907<<<<<<<<<<<<<<<
                        7408122F1204159UTO<<<<<<<<<<<6
                        ERIKSSON<<ANNA<MARIA<<<<<<<<<<
                        """
        let result = MRZResult(
            mrzKey: "D23145890774081221204159",
            format: .td1,
            documentType: .id,
            documentTypeAdditional: nil,
            countryCode: "UTO",
            surnames: "ERIKSSON",
            givenNames: "ANNA MARIA",
            documentNumber: "D23145890",
            nationalityCountryCode: "UTO",
            birthdate: try XCTUnwrap(dateFormatter.date(from: "740812")),
            sex: .female,
            expiryDate: try XCTUnwrap(dateFormatter.date(from: "120415")),
            optionalData: nil,
            optionalData2: nil
        )

        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: true), result)
        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: false), result)
    }

    func testTD2() throws {
        let mrzString = """
                        IRUTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<
                        D231458907UTO7408122F1204159<<<<<<<6
                        """
        let result = MRZResult(
            mrzKey: "D23145890774081221204159",
            format: .td2,
            documentType: .id,
            documentTypeAdditional: "R",
            countryCode: "UTO",
            surnames: "ERIKSSON",
            givenNames: "ANNA MARIA",
            documentNumber: "D23145890",
            nationalityCountryCode: "UTO",
            birthdate:  try XCTUnwrap(dateFormatter.date(from: "740812")),
            sex: .female,
            expiryDate: try XCTUnwrap(dateFormatter.date(from: "120415")),
            optionalData: nil,
            optionalData2: nil
        )

        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: true), result)
        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: false), result)
    }

    func testTD3() throws {
        let mrzString = """
                        P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<
                        L898902C36UTO7408122F1204159ZE184226B<<<<<10
                        """
        let result = MRZResult(
            mrzKey: "L898902C3674081221204159",
            format: .td3,
            documentType: .passport,
            documentTypeAdditional: nil,
            countryCode: "UTO",
            surnames: "ERIKSSON",
            givenNames: "ANNA MARIA",
            documentNumber: "L898902C3",
            nationalityCountryCode: "UTO",
            birthdate:  try XCTUnwrap(dateFormatter.date(from: "740812")),
            sex: .female,
            expiryDate: try XCTUnwrap(dateFormatter.date(from: "120415")),
            optionalData: "ZE184226B",
            optionalData2: nil
        )

        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: true), result)
        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: false), result)
    }

    func testTD3RussianInternationalPassport() throws {
        let mrzString = """
                        P<RUSIMIAREK<<EVGENII<<<<<<<<<<<<<<<<<<<<<<<
                        1104000008RUS8209120M2601157<<<<<<<<<<<<<<06
                        """
        let result = MRZResult(
            mrzKey: "110400000882091202601157",
            format: .td3,
            documentType: .passport,
            documentTypeAdditional: nil,
            countryCode: "RUS",
            surnames: "IMIAREK",
            givenNames: "EVGENII",
            documentNumber: "110400000",
            nationalityCountryCode: "RUS",
            birthdate:  try XCTUnwrap(dateFormatter.date(from: "820912")),
            sex: .male,
            expiryDate: try XCTUnwrap(dateFormatter.date(from: "260115")),
            optionalData: nil,
            optionalData2: nil
        )

        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: true), result)
        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: false), result)
    }

    func testTD3NetherlandsPassport() throws {
        let mrzString = """
                        P<NLDDE<BRUIJN<<WILLEKE<LISELOTTE<<<<<<<<<<<
                        SPECI20142NLD6503101F2403096999999990<<<<<84
                        """
        let result = MRZResult(
            mrzKey: "SPECI2014265031012403096",
            format: .td3,
            documentType: .passport,
            documentTypeAdditional: nil,
            countryCode: "NLD",
            surnames: "DE BRUIJN",
            givenNames: "WILLEKE LISELOTTE",
            documentNumber: "SPECI2014",
            nationalityCountryCode: "NLD",
            birthdate:  try XCTUnwrap(dateFormatter.date(from: "650310")),
            sex: .female,
            expiryDate: try XCTUnwrap(dateFormatter.date(from: "240309")),
            optionalData: "999999990",
            optionalData2: nil
        )

        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: true), result)
        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: false), result)
    }

    func testMRVA() throws {
        let mrzString = """
                        V<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<
                        L8988901C4XXX4009078F96121096ZE184226B<<<<<<
                        """
        let result = MRZResult(
            mrzKey: "L8988901C440090789612109",
            format: .td3,
            documentType: .visa,
            documentTypeAdditional: nil,
            countryCode: "UTO",
            surnames: "ERIKSSON",
            givenNames: "ANNA MARIA",
            documentNumber: "L8988901C",
            nationalityCountryCode: "XXX",
            birthdate:  try XCTUnwrap(dateFormatter.date(from: "19400907")),
            sex: .female,
            expiryDate: try XCTUnwrap(dateFormatter.date(from: "961210")),
            optionalData: "6ZE184226B",
            optionalData2: nil
        )

        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: true), result)
        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: false), result)
    }

    func testMRVB() throws {
        let mrzString = """
                        V<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<
                        L8988901C4XXX4009078F9612109<<<<<<<<
                        """
        let result = MRZResult(
            mrzKey: "L8988901C440090789612109",
            format: .td2,
            documentType: .visa,
            documentTypeAdditional: nil,
            countryCode: "UTO",
            surnames: "ERIKSSON",
            givenNames: "ANNA MARIA",
            documentNumber: "L8988901C",
            nationalityCountryCode: "XXX",
            birthdate:  try XCTUnwrap(dateFormatter.date(from: "19400907")),
            sex: .female,
            expiryDate: try XCTUnwrap(dateFormatter.date(from: "19961210")),
            optionalData: nil,
            optionalData2: nil
        )

        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: true), result)
        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: false), result)
    }

    /// 1 -> I correction in optionalData2 in mrzString
    func testTD1OptionalData2OCRCorrection() throws {
        let mrzString = """
                        ITNLDPS99106567SNP3048542022<<
                        8511250M2904076RUS<1<89<<<<<<7
                        ERIKSSON<<ANNA<MARIA<<<<<<<<<<
                        """
        let result = MRZResult(
            mrzKey: "PS9910656785112502904076",
            format: .td1,
            documentType: .id,
            documentTypeAdditional: "T",
            countryCode: "NLD",
            surnames: "ERIKSSON",
            givenNames: "ANNA MARIA",
            documentNumber: "PS9910656",
            nationalityCountryCode: "RUS",
            birthdate:  try XCTUnwrap(dateFormatter.date(from: "851125")),
            sex: .male,
            expiryDate: try XCTUnwrap(dateFormatter.date(from: "290407")),
            optionalData: "SNP3048542022",
            optionalData2: "I 89"
        )

        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: true), result)
        XCTAssertNil(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: false))
    }

    func testTD1withoutOptionalData2() throws {
        let mrzString = """
                        I<LVAPA99929216121282<88882<<<
                        8212122M1703054LVA<<<<<<<<<<<0
                        PARAUDZINS<<ANDRIS<<<<<<<<<<<<
                        """
        let result = MRZResult(
            mrzKey: "PA9992921682121221703054",
            format: .td1,
            documentType: .id,
            documentTypeAdditional: nil,
            countryCode: "LVA",
            surnames: "PARAUDZINS",
            givenNames: "ANDRIS",
            documentNumber: "PA9992921",
            nationalityCountryCode: "LVA",
            birthdate:  try XCTUnwrap(dateFormatter.date(from: "821212")),
            sex: .male,
            expiryDate: try XCTUnwrap(dateFormatter.date(from: "170305")),
            optionalData: "121282 88882",
            optionalData2: nil
        )

        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: true), result)
        XCTAssertEqual(MRZParser.parse(mrzString: mrzString, isOCRCorrectionEnabled: false), result)
    }
}
