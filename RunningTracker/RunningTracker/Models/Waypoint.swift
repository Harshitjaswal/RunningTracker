//
//  Waypoint.swift
//  RunningTracker
//
//  Created by Harshit on 11/07/26.
//

import Foundation
import CoreLocation

struct Waypoint: Codable, Identifiable, Sendable {
    let id: UUID
    let lat: Double
    let lon: Double
    let elevation: Double?

    nonisolated var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    init(lat: Double, lon: Double, elevation: Double? = nil) {
        self.id = UUID()
        self.lat = lat
        self.lon = lon
        self.elevation = elevation
    }

    enum CodingKeys: String, CodingKey { case lat, lon, elevation }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.lat = try c.decode(Double.self, forKey: .lat)
        self.lon = try c.decode(Double.self, forKey: .lon)
        self.elevation = try c.decodeIfPresent(Double.self, forKey: .elevation)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lat, forKey: .lat)
        try c.encode(lon, forKey: .lon)
        try c.encodeIfPresent(elevation, forKey: .elevation)
    }
}
