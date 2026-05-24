//
//  NetworkService.swift
//  NetworkKit
//
//  Created by beyyzgur on 24.05.2026.
//

import Foundation

public protocol NetworkServiceProtocol: Sendable {
    func request<T: Decodable & Sendable>(endpoint: any Endpoint) async throws -> T
    func requestWithoutResponse(endpoint: any Endpoint) async throws
}

public final class NetworkService: NetworkServiceProtocol {

    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public func request<T: Decodable & Sendable>(endpoint: any Endpoint) async throws -> T {
        let urlRequest = try buildRequest(from: endpoint)
        let (data, response) = try await urlSession.data(for: urlRequest)
        try validate(response: response, data: data)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }

    public func requestWithoutResponse(endpoint: any Endpoint) async throws {
        let urlRequest = try buildRequest(from: endpoint)
        let (data, response) = try await urlSession.data(for: urlRequest)
        try validate(response: response, data: data)
    }
}

// MARK: - Private
private extension NetworkService {

    func buildRequest(from endpoint: any Endpoint) throws -> URLRequest {
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = endpoint.headers
        request.httpBody = endpoint.body
        return request
    }

    func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        default:
            if let backendError = try? JSONDecoder().decode(NetworkErrorResponse.self, from: data) {
                throw NetworkError.backendMessage(backendError.error.message)
            }

            switch httpResponse.statusCode {
            case 401: throw NetworkError.unauthorized
            case 403: throw NetworkError.forbidden
            case 404: throw NetworkError.notFound
            case 500...599: throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            default: throw NetworkError.unknown(statusCode: httpResponse.statusCode)
            }
        }
    }
}

// MARK: - Private Models
private struct NetworkErrorResponse: Decodable {
    let error: NetworkErrorPayload
}

private struct NetworkErrorPayload: Decodable {
    let message: String
}
