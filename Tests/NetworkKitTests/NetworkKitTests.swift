//
//  NetworkKitTests.swift
//  NetworkKit
//

import XCTest
@testable import NetworkKit

// MARK: - Mock Models
private struct MockResponse: Codable, Sendable, Equatable {
    let id: Int
    let name: String
}

// MARK: - Mock NetworkService
private actor MockNetworkService: NetworkServiceProtocol {
    
    enum Behavior {
        case success(Data)
        case failure(NetworkError)
    }
    
    private var behavior: Behavior
    
    init(behavior: Behavior) {
        self.behavior = behavior
    }
    
    func request<T: Decodable & Sendable>(endpoint: any Endpoint) async throws -> T {
        switch behavior {
        case .success(let data):
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError
            }
        case .failure(let error):
            throw error
        }
    }
    
    func requestWithoutResponse(endpoint: any Endpoint) async throws {
        switch behavior {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - NetworkServiceTests
final class NetworkServiceTests: XCTestCase {
    
    // MARK: - Happy Path
    func testRequestDecodesSuccessfully() async throws {
        let expected = MockResponse(id: 1, name: "NetworkKit")
        let data = try JSONEncoder().encode(expected)
        let sut = MockNetworkService(behavior: .success(data)) // sut => system under test
        
        let result: MockResponse = try await sut.request(endpoint: MockEndpoint())
        XCTAssertEqual(result, expected)
    }
    
    func testRequestWithoutResponseSucceeds() async throws {
        let sut = MockNetworkService(behavior: .success(Data()))
        try await sut.requestWithoutResponse(endpoint: MockEndpoint())
    }
    
    // MARK: - Unhappy Path
    func testInvalidURLThrowsError() async {
        let sut = MockNetworkService(behavior: .failure(.invalidURL))
        await XCTAssertThrowsNetworkError(
            try await sut.request(endpoint: MockEndpoint()) as MockResponse,
            expected: .invalidURL
        )
    }
    
    func testUnauthorizedThrowsError() async {
        let sut = MockNetworkService(behavior: .failure(.unauthorized))
        await XCTAssertThrowsNetworkError(
            try await sut.request(endpoint: MockEndpoint()) as MockResponse,
            expected: .unauthorized
        )
    }
    
    func testForbiddenThrowsError() async {
        let sut = MockNetworkService(behavior: .failure(.forbidden))
        await XCTAssertThrowsNetworkError(
            try await sut.request(endpoint: MockEndpoint()) as MockResponse,
            expected: .forbidden
        )
    }
    
    func testNotFoundThrowsError() async {
        let sut = MockNetworkService(behavior: .failure(.notFound))
        await XCTAssertThrowsNetworkError(
            try await sut.request(endpoint: MockEndpoint()) as MockResponse,
            expected: .notFound
        )
    }
    
    func testServerErrorThrowsError() async {
        let sut = MockNetworkService(behavior: .failure(.serverError(statusCode: 500)))
        await XCTAssertThrowsNetworkError(
            try await sut.request(endpoint: MockEndpoint()) as MockResponse,
            expected: .serverError(statusCode: 500)
        )
    }
    
    func testDecodingErrorThrowsError() async {
        let sut = MockNetworkService(behavior: .success(Data("invalid json".utf8)))
        await XCTAssertThrowsNetworkError(
            try await sut.request(endpoint: MockEndpoint()) as MockResponse,
            expected: .decodingError
        )
    }
    
    func testBackendMessageThrowsError() async {
        let sut = MockNetworkService(behavior: .failure(.backendMessage("API key is invalid")))
        await XCTAssertThrowsNetworkError(
            try await sut.request(endpoint: MockEndpoint()) as MockResponse,
            expected: .backendMessage("API key is invalid")
        )
    }
}

// MARK: - Mock Endpoint
private struct MockEndpoint: Endpoint {
    var baseURL: String = "https://mock.api.com"
    var path: String = "/test"
    var method: HttpMethod = .get
    var queryItems: [URLQueryItem]? = nil
    var headers: [String: String]? = nil
    var body: Data? = nil
}

// MARK: - Custom Assertion
private func XCTAssertThrowsNetworkError<T>(
    _ expression: @autoclosure () async throws -> T,
    expected: NetworkError,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Hata fırlatılması bekleniyordu", file: file, line: line)
    } catch let error as NetworkError {
        XCTAssertEqual(
            error,
            expected,
            file: file,
            line: line
        )
    } catch {
        XCTFail("Beklenmedik hata türü: \(error)", file: file, line: line)
    }
}
