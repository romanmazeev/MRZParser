//
//  String+TrimmingFillers.swift
//  
//
//  Created by Roman Mazeev on 15.06.2021.
//

import Foundation

extension String {
    var trimmingFillers: String {
        return trimmingCharacters(in: CharacterSet(charactersIn: "<"))
    }

    func replace(_ target: String, with: String) -> String {
        replacingOccurrences(of: target, with: with, options: .literal, range: nil)
    }

    func substring(_ from: Int, to: Int) -> String {
        let fromIndex = index(startIndex, offsetBy: from)
        let toIndex = index(startIndex, offsetBy: to + 1)
        return String(self[fromIndex..<toIndex])
    }
}
