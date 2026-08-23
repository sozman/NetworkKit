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

private struct CustomErrorResponse: Decodable, Error, Sendable, Equatable {
    let code: Int
    let detail: String
}

private final class ErrorURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 422,
                httpVersion: nil,
                headerFields: nil
              ) else {
            client?.urlProtocol(self, didFailWithError: NetworkError.invalidResponse)
            return
        }

        let data = if request.url?.path == "/default-error" {
            Data(#"{"error":{"message":"Default error message"}}"#.utf8)
        } else {
            Data(#"{"code":1001,"detail":"Invalid request"}"#.utf8)
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(
            self,
            didLoad: data
        )
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Mock NetworkService
private actor MockNetworkService: NetworkServiceProtocol {
    typealias ErrorModel = MockResponse
    
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

    func testRequestThrowsProvidedCustomErrorModel() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ErrorURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        let sut = NetworkService<CustomErrorResponse>(
            urlSession: urlSession
        )

        do {
            let _: MockResponse = try await sut.request(endpoint: MockEndpoint())
            XCTFail("CustomErrorResponse fırlatılması bekleniyordu")
        } catch let error as CustomErrorResponse {
            XCTAssertEqual(
                error,
                CustomErrorResponse(code: 1001, detail: "Invalid request")
            )
        } catch {
            XCTFail("Beklenmedik hata türü: \(error)")
        }
    }

    func testRequestThrowsDefaultErrorWithoutCustomErrorModel() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ErrorURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        let sut = NetworkService(urlSession: urlSession)

        await XCTAssertThrowsNetworkError(
            try await sut.request(endpoint: MockEndpoint(path: "/default-error")) as MockResponse,
            expected: .backendMessage("Default error message")
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
