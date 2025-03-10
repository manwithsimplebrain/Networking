//
//  KeychainStorage.swift
//  Networking
//
//  Created by Dat Doan on 6/3/25.
//

import Foundation

@propertyWrapper
struct KeychainStorage<T: Codable>{
    private let key: String
    private let service: String
    private let group: String?
    private let synchronize: Bool
    private var defaultValue: T
    
    init(key: String,
         service: String = Bundle.main.bundleIdentifier ?? "",
         group: String? = nil,
         defaultValue: T,
         synchronize: Bool = false) {
        self.key = key
        self.service = service
        self.group = group
        self.defaultValue = defaultValue
        self.synchronize = synchronize
    }
    
    var wrappedValue: T {
        get {
            let query = baseQuery
                .adding(kSecReturnData as String, value: true)
                .adding(kSecMatchLimit as String, value: kSecMatchLimitOne) as CFDictionary
            var data: AnyObject?
            let status = SecItemCopyMatching(query, &data)
            guard status == errSecSuccess, let data = data as? Data else {
                return defaultValue
            }
            
            if T.self == Data.self {
                return data as! T
            }
            if T.self == String.self {
                return String(data: data, encoding: .utf8) as? T ?? defaultValue
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                print("Keychain decode error: \(error)")
                return defaultValue
            }
        }
        set {
            if let optional = newValue as? MaybeOptional, optional.isNil {
                deleteKeychainItem()
                return
            }
            let data: Data?
            if let value = newValue as? Data {
                data = value
            } else if let value = newValue as? String {
                data = value.data(using: .utf8)
            } else {
                do {
                    data = try JSONEncoder().encode(newValue)
                } catch {
                    print("Keychain encode error: \(error)")
                    return
                }
            }
            guard let data else { return }
            saveKeychainItem(data)
        }
    }
}

extension KeychainStorage {
    private var baseQuery: [String: Any] {
        var query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrService: service as Any
        ] as [String: Any]
        
        if let group {
            query[kSecAttrAccessGroup as String] = group
        }
        
        if synchronize {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue
        }
        
        return query
    }
    
    private func deleteKeychainItem() {
        let query = baseQuery as CFDictionary
        _ = SecItemDelete(query)
    }
    
    private func saveKeychainItem(_ data: Data) {
        deleteKeychainItem()
        
        let query = baseQuery
            .adding(kSecValueData as String, value: data)
            .adding(kSecAttrAccessible as String, value: kSecAttrAccessibleAfterFirstUnlock)
        _ = SecItemAdd(query as CFDictionary, nil)
    }
}

extension Dictionary {
    func adding(_ key: Key, value: Value) -> Self {
        var dict = self
        dict[key] = value
        return dict
    }
}

protocol MaybeOptional {
    var isNil: Bool { get }
}

extension Optional: MaybeOptional {
    var isNil: Bool {
        switch self {
        case .none: return true
        case .some: return false
        }
    }
}
