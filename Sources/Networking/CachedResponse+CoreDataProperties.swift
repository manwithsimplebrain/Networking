//
//  CachedResponse+CoreDataProperties.swift
//  Networking
//
//  Created by Dat Doan on 10/3/25.
//
//

import Foundation
import CoreData


extension CachedResponse {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedResponse> {
        return NSFetchRequest<CachedResponse>(entityName: "CachedResponse")
    }

    @NSManaged public var key: String
    @NSManaged public var data: Data
    @NSManaged public var timestamp: Date
    @NSManaged public var ttl: NSNumber?
    
    var ttlValue: TimeInterval? {
        get { ttl?.doubleValue }
        set { ttl = newValue.map { NSNumber(value: $0) } }
    }

}
