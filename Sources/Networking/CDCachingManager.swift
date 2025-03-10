import Foundation
import CoreData

actor CDCachingManager: CacheManager {
    private lazy var container: NSPersistentContainer = {
        print(Bundle.module.bundleURL)
        guard let modelURL = Bundle.module.url(forResource: "Caching", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Core Data Model not found")
        }
        
        let container = NSPersistentContainer(name: "Caching", managedObjectModel: model)
        
//        // Configure persistent store
//        if let storeURL = container.persistentStoreDescriptions.first?.url {
//            let description = NSPersistentStoreDescription(url: storeURL)
//            description.shouldMigrateStoreAutomatically = true
//            description.shouldInferMappingModelAutomatically = true
//            container.persistentStoreDescriptions = [description]
//        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load Core Data: \(error)")
            }
        }
        
        return container
    }()
    
    // Sử dụng background context với merge policy cố định
    private lazy var context: NSManagedObjectContext = {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }()
    
    func save(_ metadata: CacheMetadata, for key: String) async {
        let ctx = context
        context.performAndWait {
            let cachedResponse = CachedResponse(context: ctx)
            cachedResponse.key = key
            cachedResponse.data = metadata.data
            cachedResponse.timestamp = Date()
            cachedResponse.ttlValue = metadata.ttl
            
            do {
                try ctx.save()
            } catch {
                print("Save error: \(error)")
                ctx.rollback()
            }
        }
    }

    func get(for key: String) async -> CacheMetadata? {
        let ctx = context
        return context.performAndWait {
            let request = CachedResponse.fetchRequest()
            request.predicate = NSPredicate(format: "key == %@", key)
            
            do {
                return try ctx.fetch(request).first.map { CacheMetadata(data: $0.data, ttl: $0.ttlValue) }
            } catch {
                print("Fetch error: \(error)")
                return nil
            }
        }
    }
}
