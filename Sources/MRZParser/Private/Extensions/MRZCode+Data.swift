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
    public init(identifier: Character) {
        switch identifier {
        case Self.visa.identifier:
            self = .visa
        case Self.passport.identifier:
            self = .passport
        default:
            self = .other(identifier)
        }
    }

    public var identifier: Character {
        switch self {
        case .visa:
            return "V"
        case .passport:
            return "P"
        case .other(let value):
            return value
        }
    }
}

extension MRZCode.DocumentSubtype {
    public init(identifier: Character) {
        switch identifier {
        case Self.national.identifier:
            self = .national
        default:
            self = .other(identifier)
        }
    }

    public var identifier: Character {
        switch self {
        case .national:
            return "N"
        case .other(let value):
            return value
        }
    }
}

extension MRZCode.Sex {
    public init(identifier: Character) {
        switch identifier {
        case Self.male.identifier:
            self = .male
        case Self.female.identifier:
            self = .female
        default:
            self = .other(identifier)
        }
    }

    public var identifier: Character {
        switch self {
        case .male:
            return "M"
        case .female:
            return "F"
        case .unspecified:
            return "<"
        case .other(let value):
            return value
        }
    }
}

extension MRZCode.Country {
    public init(identifier: String) {
        switch identifier {
        case Self.russia.identifier:
            self = .russia
        default:
            self = .other(identifier)
        }
    }

    public var identifier: String {
        switch self {
        case .russia:
            return "RUS"
        case .other(let value):
            return value
        }
    }
}
