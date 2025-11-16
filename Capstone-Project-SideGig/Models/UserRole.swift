//
//  UserRole.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//


import Foundation

enum UserRole: String, Codable, CaseIterable, Identifiable, Hashable {
    case seeker
    case business
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .seeker:
            return "Seeker"
        case .business:
            return "Business"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .seeker:
            return "person.fill.badge.plus"
        case .business:
            return "building.2.fill"
        }
    }
}
