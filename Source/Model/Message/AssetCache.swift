
//
//  AssetDirectory.swift
//  zmessaging-cocoa
//
//  Created by Marco Conti on 07/10/15.
//  Copyright (c) 2015 Zeta Project Gmbh. All rights reserved.
//

import Foundation
import ZMCSystem
import zimages
import PINCache

private let NSManagedObjectContextImageAssetCacheKey = "zm_imageAssetCache"

extension NSManagedObjectContext
{
    public var zm_imageAssetCache : ImageAssetCache {
        get {
            return self.userInfo[NSManagedObjectContextImageAssetCacheKey] as! ImageAssetCache
        }
        
        set {
            self.userInfo[NSManagedObjectContextImageAssetCacheKey] = newValue
        }
    }
}

protocol Cache {
    
    /// Returns the asset data for a given key. This will probably cause I/O
    func assetData(key: String) -> NSData?
    
    /// Returns the file URL (if any) for a given key.
    func assetURL(key: String) -> NSURL?
    
    /// Stores the asset data for a given key. This will probably cause I/O
    func storeAssetData(data: NSData, key: String)
    
    /// Stores the asset data for a source url that must be a local file. This will probably cause I/O
    func storeAssetFromURL(url: NSURL, key: String)
    
    /// Deletes the data for a key. This will cause I/O
    func deleteAssetData(key: String)
}


/// Cache for assets contained in messages
struct PINAssetCache : Cache {
    
    let assetsCache : PINCache
    
    /// Creates an asset cache
    /// - parameter name: name of the cache
    /// - parameter MBLimit: maximum size of the cache on disk in MB
    init(name: String, MBLimit : UInt) {
        self.assetsCache = PINCache(name: name)
        self.assetsCache.makeURLSecure()
        self.assetsCache.configureLimits(MBLimit * 1024 * 1024)
    }
    
    func assetURL(key: String) -> NSURL? {
        return nil // URLs on disk generated by this cache are not binary dumps of the data,
                    // but archived NSData and should not be accessed directly, so this returns nil
    }
    
    func assetData(key: String) -> NSData? {
        return self.assetsCache.objectForKey(key) as? NSData
    }
    
    func storeAssetFromURL(url: NSURL, key: String) {
        guard url.scheme == NSURLFileScheme, let data = NSData(contentsOfURL: url) else { fatal("Can't read data from URL \(url)") }
        self.storeAssetData(data, key: key)
    }
    
    func storeAssetData(data: NSData, key: String) {
        self.assetsCache.setObject(data, forKey: key)
    }
    
    func deleteAssetData(key: String) {
        self.assetsCache.removeObjectForKey(key)
    }
    
    func wipeCache() {
        assetsCache.removeAllObjects()
    }
}

// MARK: - Image assets
public class ImageAssetCache : NSObject {

    let cache : PINAssetCache
    
    /// Creates an asset cache for images
    /// - parameter MBLimit: maximum size of the cache on disk in MB
    public init(MBLimit: UInt) {
        self.cache = PINAssetCache(name: "images", MBLimit: MBLimit)
    }
    
    /// Returns the asset data for a given message and format tag. This will probably cause I/O
    public func assetData(messageID: NSUUID, format: ZMImageFormat, encrypted: Bool) -> NSData? {
        return self.cache.assetData(self.dynamicType.cacheKeyForAsset(messageID, format: format, encrypted: encrypted))
    }
    
    /// Sets the asset data for a given message and format tag. This will cause I/O
    public func storeAssetData(messageID: NSUUID, format: ZMImageFormat, encrypted: Bool, data: NSData) {
        self.cache.storeAssetData(data, key: self.dynamicType.cacheKeyForAsset(messageID, format: format, encrypted: encrypted))
    }
    
    /// Deletes the data for a given message and format tag. This will cause I/O
    public func deleteAssetData(messageID: NSUUID, format: ZMImageFormat, encrypted: Bool) {
        self.cache.deleteAssetData(self.dynamicType.cacheKeyForAsset(messageID, format: format, encrypted: encrypted))
    }
    
    /// Returns the cache key for an asset
    static func cacheKeyForAsset(messageID: NSUUID, format: ZMImageFormat) -> String {
        return self.cacheKeyForAsset(messageID, format: format, encrypted: false);
    }
    
    /// Returns the cache key for an asset
    static func cacheKeyForAsset(messageID: NSUUID, format: ZMImageFormat, encrypted: Bool) -> String {
        let tagComponent = StringFromImageFormat(format)
        let encryptedComponent = encrypted ? "_encrypted" : ""
        return "\(messageID.transportString())_\(tagComponent)\(encryptedComponent)"
    }
}

public extension ImageAssetCache {
    func wipeCache() {
        cache.wipeCache()
    }
}
