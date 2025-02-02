//
//  MRZField.swift
//  
//
//  Created by Roman Mazeev on 15.06.2021.
//

import Foundation

// MARK: - BasicFields

typealias NamesField = (surnames: String, givenNames: String)

// MARK: ValidatedField

protocol ValidatedFieldProtocol {
    var rawValue: String { get }
    var checkDigit: Int? { get }
    var isValid: Bool { get }
}

struct ValidatedField<T>: ValidatedFieldProtocol {
    let value: T
    let rawValue: String
    let checkDigit: Int?

    var isValid: Bool {
        return MRZCode.isValueValid(rawValue, checkDigit: checkDigit)
    }
}
