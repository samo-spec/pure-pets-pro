//
//  PPInventoryFamilyGrouping.swift
//  PurePetsPro
//
//  Collapses the provider marketplace inventory list so logical product families
//  appear as unified, category-defining cards with options swatches, size pills,
//  aggregated stock, and price ranges, with expandable sub-variant inspectors.
//

import Foundation
import UIKit

@objc public final class PPProviderMarketDisplayGroup: NSObject {
    @objc public let isFamily: Bool
    @objc public let familyId: String?
    @objc public let singleItem: PPProviderMarketItem?
    @objc public let members: [PPProviderMarketItem]
    @objc public var isExpanded: Bool = false

    @objc public init(single item: PPProviderMarketItem) {
        self.isFamily = false
        self.familyId = nil
        self.singleItem = item
        self.members = [item]
        super.init()
    }

    @objc public init(familyId: String, members: [PPProviderMarketItem]) {
        self.isFamily = true
        self.familyId = familyId
        self.singleItem = nil
        self.members = members
        super.init()
    }

    // MARK: - Computed Properties for UI

    @objc public var defaultMember: PPProviderMarketItem {
        members.first { $0.isDefaultVariant } ?? members.first ?? PPProviderMarketItem()
    }

    @objc public var activeMembers: [PPProviderMarketItem] {
        members.filter { !$0.isArchived }
    }

    @objc public var totalStock: Int {
        activeMembers.reduce(0) { $0 + max(0, $1.quantity) }
    }

    @objc public var hasLowStock: Bool {
        activeMembers.contains { $0.quantity > 0 && $0.quantity <= 5 }
    }

    @objc public var hasOutOfStock: Bool {
        activeMembers.contains { $0.noStock || $0.quantity <= 0 }
    }

    @objc public var priceRangeString: String {
        let prices = activeMembers.map { $0.finalPrice > 0 ? $0.finalPrice : $0.price }.filter { $0 > 0 }.sorted()
        guard let minPrice = prices.first, let maxPrice = prices.last else {
            let p = defaultMember.finalPrice > 0 ? defaultMember.finalPrice : defaultMember.price
            return String(format: "%.0f QAR", p)
        }
        if abs(maxPrice - minPrice) < 0.01 {
            return String(format: "%.0f QAR", minPrice)
        }
        return String(format: "%.0f – %.0f QAR", minPrice, maxPrice)
    }

    @objc public var optionsBadgeString: String {
        guard isFamily else { return "" }
        let count = activeMembers.count
        var badges: [String] = []

        // Colors count
        let uniqueColors = Set(activeMembers.compactMap {
            let hex = $0.pos_variantColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
            return ($0.pos_hasRealColor && !hex.isEmpty) ? hex : nil
        }).count
        if uniqueColors > 1 {
            badges.append(String(format: Language.get("Variant_Badge_Colors_Format", alter: "%ld ألوان"), uniqueColors))
        }

        // Total variants count
        badges.append(String(format: Language.get("Variant_Badge_Variants_Format", alter: "%ld خياراً"), count))
        return badges.joined(separator: " • ")
    }

    @objc public var swatchesHexes: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for m in activeMembers {
            let hex = m.pos_variantColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
            if !hex.isEmpty && m.pos_hasRealColor && seen.insert(hex).inserted {
                result.append(hex)
            }
        }
        return result
    }

    @objc public var sizePillsTexts: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for m in activeMembers {
            let label = m.pos_variantOptionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty && seen.insert(label).inserted {
                result.append(label)
            }
        }
        return result
    }

    // MARK: - Grouping Engine

    @objc public static func groupedItems(_ items: [PPProviderMarketItem]) -> [PPProviderMarketDisplayGroup] {
        var order: [String] = []
        var byFamily: [String: [PPProviderMarketItem]] = [:]
        var singles: [String: PPProviderMarketItem] = [:]

        for item in items {
            let familyId = (item.productFamilyId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if familyId.isEmpty {
                let key = "item:\(item.itemID.isEmpty ? UUID().uuidString : item.itemID)"
                order.append(key)
                singles[key] = item
            } else {
                let key = "family:\(familyId)"
                if byFamily[familyId] == nil {
                    order.append(key)
                    byFamily[familyId] = []
                }
                byFamily[familyId]?.append(item)
            }
        }

        return order.compactMap { key in
            if let item = singles[key] {
                return PPProviderMarketDisplayGroup(single: item)
            }
            let familyId = String(key.dropFirst("family:".count))
            guard let members = byFamily[familyId], !members.isEmpty else { return nil }
            if members.count == 1 {
                return PPProviderMarketDisplayGroup(single: members[0])
            }
            let sorted = members.sorted { lhs, rhs in
                lhs.variantSortOrder == rhs.variantSortOrder
                    ? lhs.itemID < rhs.itemID
                    : lhs.variantSortOrder < rhs.variantSortOrder
            }
            return PPProviderMarketDisplayGroup(familyId: familyId, members: sorted)
        }
    }
}
