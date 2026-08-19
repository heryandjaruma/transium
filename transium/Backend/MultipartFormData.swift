//
//  MultipartFormData.swift
//  transium
//

import Foundation

public struct MultipartFormData: Sendable {
    public let boundary: String
    private var data: Data

    public init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
        self.data = Data()
    }

    public mutating func appendField(name: String, value: String) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(value)\r\n".data(using: .utf8)!)
    }

    public mutating func appendFile(
        fieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data
    ) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
    }

    public func finalize() -> Data {
        var finalized = data
        finalized.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return finalized
    }

    public var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }
}
