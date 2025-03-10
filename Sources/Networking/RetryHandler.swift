//
//  RetryHandler.swift
//  Networking
//
//  Created by Dat Doan on 5/3/25.
//

import Foundation

public protocol RetryHandler: Sendable {
    func retry(for request: Request, operation: @Sendable @escaping () async throws -> Data) async throws -> Data
}
