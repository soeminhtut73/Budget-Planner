//
//  AmountInput.swift
//  Pocket Ledger
//
//  Pure model backing the number pad. Tracks the integer and fraction parts
//  the user types and produces an exact Decimal. Fraction length is capped at
//  the currency's minor units; the "." key is inert for 0-minor currencies.
//

import Foundation

struct AmountInput: Equatable {
    let minorUnits: Int
    private(set) var integer: String = ""
    private(set) var fraction: String = ""
    private(set) var enteringFraction = false

    init(minorUnits: Int) {
        self.minorUnits = max(0, minorUnits)
    }

    /// Exact value of what has been entered (0 when empty).
    var value: Decimal {
        let intPart = integer.isEmpty ? "0" : integer
        let combined = enteringFraction && !fraction.isEmpty ? "\(intPart).\(fraction)" : intPart
        return Decimal(string: combined) ?? 0
    }

    var isEmpty: Bool {
        integer.isEmpty && fraction.isEmpty && !enteringFraction
    }

    mutating func tapDigit(_ digit: Int) {
        guard (0...9).contains(digit) else { return }
        let s = String(digit)
        if enteringFraction {
            guard fraction.count < minorUnits else { return }
            fraction.append(s)
        } else if integer == "0" {
            integer = s                  // replace a lone leading zero
        } else if integer.count < 12 {   // guard against absurd amounts
            integer.append(s)
        }
    }

    mutating func tapDot() {
        guard minorUnits > 0, !enteringFraction else { return }
        enteringFraction = true
        if integer.isEmpty { integer = "0" }
    }

    mutating func tapDelete() {
        if enteringFraction {
            if !fraction.isEmpty { fraction.removeLast() }
            else { enteringFraction = false }
        } else if !integer.isEmpty {
            integer.removeLast()
        }
    }

    mutating func clear() {
        integer = ""
        fraction = ""
        enteringFraction = false
    }

    /// Seeds the input from an existing amount (for edit mode).
    static func from(_ amount: Decimal, minorUnits: Int) -> AmountInput {
        var input = AmountInput(minorUnits: minorUnits)
        let rounded = CurrencyRounding.rounded(amount, scale: minorUnits)
        let whole = (rounded as NSDecimalNumber).intValue
        input.integer = String(whole)
        if minorUnits > 0 {
            let fractionValue = rounded - Decimal(whole)
            if fractionValue > 0 {
                let scaled = fractionValue * pow(Decimal(10), minorUnits)
                let digits = (scaled as NSDecimalNumber).intValue
                let padded = String(format: "%0\(minorUnits)d", digits)
                input.enteringFraction = true
                input.fraction = padded
            }
        }
        return input
    }
}
