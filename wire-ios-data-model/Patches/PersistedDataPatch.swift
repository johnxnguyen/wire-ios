//
//  PersistedDataPatch.swift
//  WireDataModel
//
//  Created by John Ranjith on 11/13/22.
//  Copyright © 2022 Wire Swiss GmbH. All rights reserved.
//

import Foundation

private let zmLog = ZMSLog(tag: "Patches")

//extension PersistedDataPatch {
public final class PersistedDataPatch {
    
    var version: Int = 0
    //var name: String = "patch1"
    let block: (NSManagedObjectContext)->()
    
    static let allPatchesToApply = [
        PersistedDataPatch(version: 1, block: UserClient.migrateAllSessionsClientIdentifiersV2),
        PersistedDataPatch(version: 2, block: ZMConversation.migrateAllSecureWithIgnored)]
    
    
    public init(version: Int, block: @escaping (NSManagedObjectContext)->()) {
    //public init(version: Int, name:String) {
        self.version = version
        self.block = block
    }

    public static func applyAll(in context: NSManagedObjectContext,patches: [PersistedDataPatch]? = nil) {
        
        
        // Get the current version
        let currentVersion = allPatchesToApply.count
        
        print("PersistedDataPatch applyAll")
        print("currentVersion PersistedDataPatch\(currentVersion)")
        defer {
            context.setPersistentStoreMetadata(currentVersion, key: "lastRunPatchVersion")
            context.saveOrRollback()
        }
        
        // Get the previous version
        guard let previousVersion = context.persistentStoreMetadata(forKey: "lastRunPatchVersion") as? Int else {
            // no version was run, this is a fresh install, skipping...
            return
        }
        
        (patches ?? allPatchesToApply).filter { $0.version > previousVersion }.forEach {
            $0.block(context)
        }
    }
}
