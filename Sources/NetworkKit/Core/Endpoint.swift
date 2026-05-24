//
//  Endpoint.swift
//  NetworkKit
//
//  Created by beyyzgur on 24.05.2026.
//

import Foundation

public protocol Endpoint: Sendable {
    var baseURL: String { get }
    var path: String { get }
    var method: HttpMethod { get }
    var queryItems: [URLQueryItem]? { get }
    var headers: [String: String]? { get }
    var body: Data? { get }
}

public extension Endpoint {
    var body: Data? { nil }
    
    var url: URL? {
        var components = URLComponents(string: baseURL + path)
        components?.queryItems = queryItems
        return components?.url
    }
}
