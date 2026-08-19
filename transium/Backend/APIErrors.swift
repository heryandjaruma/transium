//
//  APIErrors.swift
//  transium
//

import Foundation

public enum TransiumAPIError: LocalizedError, Sendable {
    case invalidURL
    case invalidRequest(String)
    case unauthorized
    case forbidden
    case notFound(String)
    case conflict(String)
    case unprocessableEntity(String)
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)
    case serviceUnavailable(String)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL."
        case .invalidRequest(let message):
            return message.isEmpty ? "Invalid request arguments." : message
        case .unauthorized:
            return "Session expired or unauthorized. Please sign in again."
        case .forbidden:
            return "You do not have permission to perform this action."
        case .notFound(let message):
            return message.isEmpty ? "Resource not found." : message
        case .conflict(let message):
            return message.isEmpty ? "Conflict with existing resource." : message
        case .unprocessableEntity(let message):
            return message.isEmpty ? "Unprocessable request." : message
        case .serverError(let statusCode, let message):
            return message.isEmpty ? "Server error (\(statusCode))." : message
        case .decodingError(let error):
            return "Failed to parse server response: \(error.localizedDescription)"
        case .networkError(let error):
            return error.localizedDescription
        case .serviceUnavailable(let message):
            return message.isEmpty ? "Service temporarily unavailable." : message
        case .unknown:
            return "An unknown error occurred."
        }
    }
}
