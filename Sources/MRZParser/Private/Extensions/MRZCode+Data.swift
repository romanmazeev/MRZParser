//
//  MRZCode+Data.swift
//  MRZParser
//
//  Created by Roman Mazeev on 09/02/2025.
//

extension MRZCode.Format {
    public var lineLength: Int {
        switch self {
        case .td1:
            return 30
        case .td2:
            return 36
        case .td3:
            return 44
        }
    }

    public var linesCount: Int {
        switch self {
        case .td1:
            return 3
        case .td2, .td3:
            return 2
        }
    }
}

extension MRZCode.DocumentType {
    var identifier: Character {
        switch self {
        case .visa:
            return "V"
        case .passport:
            return "P"
        case .id:
            return "I"
        case .undefined:
            return "_"
        }
    }
}

extension MRZCode.Sex {
    var identifier: [String] {
        switch self {
        case .male:
            return ["M"]
        case .female:
            return ["F"]
        case .unspecified:
            return ["X", "<", " "]
        }
    }
}
