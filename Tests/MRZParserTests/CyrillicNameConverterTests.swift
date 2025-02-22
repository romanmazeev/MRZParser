//
//  CyrillicNameConverterTests.swift
//  MRZParser
//
//  Created by Roman Mazeev on 22/02/2025.
//

import XCTest
@testable import MRZParser

final class CyrillicNameConverterTests: XCTestCase {
    func testConvert() {
        XCTAssertEqual(
            CyrillicNameConverter.liveValue.convert("ABVGDE2JZIQKLMNOPRSTUFHC34WXY96785"),
            "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ5"
        )
    }
}
