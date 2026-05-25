# NetworkKit

Lightweight, protocol-driven HTTP networking library. Built with Swift 6.

## Requirements
- iOS 17+
- Swift 6+

## Core Components
- `Endpoint` — Protocol for defining API endpoints
- `HttpMethod` — GET, POST, PUT, DELETE, PATCH
- `NetworkService` — Service that handles HTTP requests
- `NetworkError` — Error cases

## Usage

```swift
// 1. Define an endpoint
enum UserRouter: Endpoint {
    case getUser(id: String)
    
    var baseURL: String { "https://api.example.com" }
    var path: String { "/users/\(id)" }
    var method: HttpMethod { .get }
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String: String]? { nil }
}

// 2. Make a request
let service = NetworkService()
let user: User = try await service.request(endpoint: UserRouter.getUser(id: "1"))
```
