//
//  RouteLoader.swift
//  RunningTracker
//
//  Created by Harshit on 11/07/26.
//

import Foundation

enum RouteLoader {
    enum LoadError: Error, LocalizedError {
        case fileNotFound
        case invalidJSON
        case noRoutes
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound: return "routes.json not found in bundle"
            case .invalidJSON:  return "Invalid JSON in routes.json"
            case .noRoutes:     return "No valid routes found"
            }
        }
    }

    static func loadRoutes() throws -> [Route] {
        guard let url = Bundle.main.url(
            forResource: "routes", withExtension: "json") 
        else { throw LoadError.fileNotFound }
        
        let data = try Data(contentsOf: url)
        
        do {
            let container = try JSONDecoder().decode(
                RoutesContainer.self, from: data)
            let valid = container.routes.filter { $0.isValid }
            guard !valid.isEmpty else { throw LoadError.noRoutes }
            return valid
        } catch is DecodingError {
            throw LoadError.invalidJSON
        }
    }
}
