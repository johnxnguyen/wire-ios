//
//  SyncEnginePatches.swift
//  WireSyncEngine-ios
//
//  Created by John Ranjith on 11/8/22.
//  Copyright © 2022 Zeta Project Gmbh. All rights reserved.
//

import Foundation

private let zmLog = ZMSLog(tag: "Patches")

//extension PersistedDataPatch {
public final class SyncEnginePatches {
    
    var version: Int = 0
    let block: (NSManagedObjectContext)->()
    
    static let patchesToApply = [
        SyncEnginePatches(version: 1, block: UserClient.migrateAllSessionsClientIdentifiersV2),
        SyncEnginePatches(version: 2, block: ZMConversation.migrateAllSecureWithIgnored)]
    
    public init(version: Int, block: @escaping (NSManagedObjectContext)->()) {
        self.version = version
        self.block = block
    }

    public static func applyAll(in context: NSManagedObjectContext,patches: [SyncEnginePatches]? = nil) {
        
        // Get the current version
        let currentVersion = allPatchesToApply.count
        print("SyncEnginePatches applyAll")
        print("currentVersion SyncEnginePatches\(currentVersion)")
        defer {
            context.setPersistentStoreMetadata(currentVersion, key: "lastRunSyncPatchVersion")
            context.saveOrRollback()
        }
        // Get the previous version
        guard let previousVersion = context.persistentStoreMetadata(forKey: "lastRunSyncPatchVersion") as? Int else {
            // no version was run, this is a fresh install, skipping...
            return
        }
        (patches ?? patchesToApply).filter { $0.version > previousVersion }.forEach {
            $0.block(context)
        }
    }
}

