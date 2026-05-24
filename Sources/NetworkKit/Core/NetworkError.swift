//
//  NetworkError.swift
//  NetworkKit
//
//  Created by beyyzgur on 24.05.2026.
//

import Foundation

public enum NetworkError: Error, Sendable, Equatable {
    case invalidURL
    case encodingError
    case unauthorized
    case forbidden
    case notFound
    case serverError(statusCode: Int)
    case timeout
    case invalidResponse
    case decodingError
    case unknown(statusCode: Int)
    case backendMessage(String)
}

extension NetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Geçersiz URL."
        case .encodingError:
            return "Veri kodlama hatası."
        case .unauthorized:
            return "Yetkisiz erişim."
        case .forbidden:
            return "Erişim engellendi."
        case .notFound:
            return "Kaynak bulunamadı."
        case .serverError(let statusCode):
            return "Sunucu hatası oluştu. Kod: \(statusCode)"
        case .timeout:
            return "İstek zaman aşımına uğradı."
        case .invalidResponse:
            return "Geçersiz yanıt alındı."
        case .decodingError:
            return "Veri çözümleme hatası."
        case .unknown(let statusCode):
            return "Bilinmeyen bir hata oluştu. Kod: \(statusCode)"
        case .backendMessage(let message):
            return message
        }
    }
}
