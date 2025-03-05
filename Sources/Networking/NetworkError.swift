//
//  File 2.swift
//  Networking
//
//  Created by Dat Doan on 4/3/25.
//

import Foundation

public struct BaseError: Sendable {
    let code: Int?
    let message: String?
    
    init(code: Int? = nil, message: String? = nil) {
        self.code = code
        self.message = message
    }
}

public enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case serviceDeallocated
    case serverError(BaseError)
    case unknown
}
