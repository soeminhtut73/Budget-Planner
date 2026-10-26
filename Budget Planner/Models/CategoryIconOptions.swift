//
//  CategoryIconOptions.swift
//  Pocket Ledger
//
//  The SF Symbols a user can choose from when creating a custom category.
//  V1 uses SF Symbols only (no emoji / custom art), so the picker draws from
//  this curated list. `CategoryIcon` renders whichever one is stored.
//

import Foundation

enum CategoryIconOptions {
    /// Curated SF Symbol names for custom categories, grouped loosely by theme.
    static let all: [String] = [
        // Food & drink
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill", "birthday.cake.fill",
        // Shopping & home
        "cart.fill", "bag.fill", "giftcard.fill", "house.fill", "bolt.fill", "drop.fill",
        // Transport
        "car.fill", "bus.fill", "tram.fill", "fuelpump.fill", "airplane",
        // Bills & tech
        "doc.text.fill", "wifi", "phone.fill", "creditcard.fill", "laptopcomputer",
        // Health & personal
        "cross.case.fill", "pills.fill", "dumbbell.fill", "tshirt.fill", "scissors",
        // Leisure
        "gamecontroller.fill", "film.fill", "music.note", "book.fill", "pawprint.fill",
        // Education & work
        "graduationcap.fill", "briefcase.fill", "building.2.fill",
        // Money & misc
        "banknote.fill", "dollarsign.circle.fill", "gift.fill", "heart.fill", "star.fill", "tag.fill",
    ]

    /// The icon a new custom category starts with.
    static let `default` = "tag.fill"
}
