// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.
// 


import Foundation


public protocol UserClientObserver: NSObjectProtocol {
    func userClientDidChange(changeInfo: UserClientChangeInfo)
}

extension UserClient: ObjectInSnapshot {
    public var keysToChangeInfoMap : KeyToKeyTransformation {
        return KeyToKeyTransformation(mapping: [
                        KeyPath.keyPathForString(ZMUserClientTrusted_ByKey) : .Default,
                        KeyPath.keyPathForString(ZMUserClientIgnored_ByKey) : .Default,
                        KeyPath.keyPathForString(ZMUserClientNeedsToNotifyUserKey) : .Default,
                        KeyPath.keyPathForString(ZMUserClientFingerprintKey) : .Default
            ])
    }

    public func keyPathsForValuesAffectingValueForKey(key: String) -> KeySet {
        return KeySet(UserClient.keyPathsForValuesAffectingValueForKey(key))
    }
}

public enum UserClientChangeInfoKey: String {
    case TrustedByClientsChanged = "trustedByClientsChanged"
    case IgnoredByClientsChanged = "ignoredByClientsChanged"
    case FingerprintChanged = "fingerprintChanged"
}

@objc public class UserClientChangeInfo : ObjectChangeInfo {

    public required init(object: NSObject) {
        self.userClient = object as! UserClient
        super.init(object: object)
    }

    public var trustedByClientsChanged = false
    public var ignoredByClientsChanged = false
    public var fingerprintChanged = false
    public var needsToNotifyUserChanged = false
    public let userClient: UserClient
}

public final class UserClientObserverToken: ObjectObserverTokenContainer, UserClientObserverOpaqueToken {

    typealias InnerTokenType = ObjectObserverToken<UserClientChangeInfo, UserClientObserverToken>
    typealias Directory = ObserverTokenDirectory<UserClientChangeInfo, UserClientObserverToken, UserClient>

    private weak var observer : UserClientObserver?
    private let managedObjectContext: NSManagedObjectContext

    public init(observer: UserClientObserver, managedObjectContext: NSManagedObjectContext, userClient: UserClient) {

        self.managedObjectContext = managedObjectContext
        var wrapper : (UserClientObserverToken, UserClientChangeInfo) -> () = { _ in return }
        self.observer = observer
        
        let directory = Directory.directoryInManagedObjectContext(managedObjectContext, keyForDirectoryInUserInfo: "UserClient")

        let innerToken = directory.tokenForObject(userClient, createBlock: {
            let token = InnerTokenType.token(
                userClient,
                keyToKeyTransformation: userClient.keysToChangeInfoMap,
                keysThatNeedPreviousValue: KeyToKeyTransformation(mapping: [:]),
                managedObjectContextObserver: userClient.managedObjectContext!.globalManagedObjectContextObserver,
                observer: { wrapper($0, $1) }
            )
            return token
        })
        super.init(object: userClient, token: innerToken)
        
        // NB! The wrapper closure is created every time @c UserClientObserverToken is created, but only the first one
        // created is actually called, but for every container that been added.
        wrapper = { container, changeInfo in
            container.observer?.userClientDidChange(changeInfo)
        }
        
        innerToken.addContainer(self)
    }

    override public func tearDown() {
        if let t = self.token as? InnerTokenType {
            t.removeContainer(self)
            if t.hasNoContainers {
                t.tearDown()
                let directory = Directory.directoryInManagedObjectContext(self.managedObjectContext, keyForDirectoryInUserInfo: "UserClient")
                directory.removeTokenForObject(self.object as! NSObject)
            }
        }
    }
}
