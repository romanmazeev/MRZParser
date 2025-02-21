//
//  Field.swift
//  MRZParser
//
//  Created by Roman Mazeev on 15.06.2021.
//

import Foundation

protocol FieldProtocol: Sendable, Equatable {
    var rawValue: String { get }
    var checkDigit: Int? { get }
    var type: FieldType { get }
}

struct Field<T: Sendable & Equatable>: FieldProtocol {
    var value: T
    var rawValue: String
    let checkDigit: Int?
    let type: FieldType
}
