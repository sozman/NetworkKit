# NetworkKit

Lightweight, protocol-driven HTTP networking library. Built with Swift 6.

## Requirements
- iOS 17+
- Swift 6+

## Core Components
- `Endpoint` — API endpoint tanımlamak için protocol
- `HttpMethod` — GET, POST, PUT, DELETE, PATCH
- `NetworkService` — HTTP isteklerini yöneten servis
- `NetworkError` — Hata durumları

## Usage

```swift
// 1. Endpoint tanımla
enum UserRouter: Endpoint {
    case getUser(id: String)
    
    var baseURL: String { "https://api.example.com" }
    var path: String { "/users/\(id)" }
    var method: HttpMethod { .get }
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String: String]? { nil }
}

// 2. İstek at
let service = NetworkService()
let user: User = try await service.request(endpoint: UserRouter.getUser(id: "1"))
```
