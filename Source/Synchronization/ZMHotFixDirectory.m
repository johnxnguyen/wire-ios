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


#import "ZMHotFixDirectory.h"
#import "NSManagedObjectContext+zmessaging.h"
#import "ZMManagedObject+Internal.h"
#import "ZMConversation+Internal.h"
#import "ZMMessage+Internal.h"
#import <ZMTransport/ZMTransport.h>
#import "zmessaging.h"

@implementation ZMHotFixPatch

+ (instancetype)patchWithVersion:(NSString *)version patchCode:(ZMHotFixPatchCode)code
{
    ZMHotFixPatch *patch = [[ZMHotFixPatch alloc] init];
    patch->_code = [code copy];
    patch->_version = [version copy];
    return patch;
}

@end



@implementation ZMHotFixDirectory

- (NSArray *)patches
{
    static dispatch_once_t onceToken;
    static NSArray *patches;
    dispatch_once(&onceToken, ^{
        patches = @[
                    [ZMHotFixPatch
                     patchWithVersion:@"33.1"
                     patchCode:^(NSManagedObjectContext *context){
                         [ZMHotFixDirectory updateLastReadEventIDForConnectionRequestsOrClearedConversationsOnContext:context];
                     }],
                    [ZMHotFixPatch
                     patchWithVersion:@"38.58"
                     patchCode:^(NSManagedObjectContext *context){
                         [ZMHotFixDirectory fetchAndDeleteConnectionRequestSystemMessagesInContext:context];
                     }],
                    [ZMHotFixPatch
                     patchWithVersion:@"40.4"
                     patchCode:^(__unused NSManagedObjectContext *context){
                         [ZMHotFixDirectory resetPushTokens];
                     }],
                    [ZMHotFixPatch
                     patchWithVersion:@"40.23"
                     patchCode:^(__unused NSManagedObjectContext *context){
                         [ZMHotFixDirectory removeSharingExtension];
                     }]
                    ];
    });
    return patches;
}


+ (void)updateLastReadEventIDForConnectionRequestsOrClearedConversationsOnContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:ZMConversation.entityName];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"(%K == %d || %K != NULL) && %K > %K",
                              @"conversationType", ZMConversationTypeConnection,
                              ZMConversationClearedEventIDDataKey,
                              @"lastEventID_data", ZMConversationLastReadEventIDDataKey];
    
    NSArray *result = [context executeFetchRequestOrAssert:fetchRequest];
    
    for (ZMConversation *conversation in result){
        if (!conversation.isSelfAnActiveMember || conversation.conversationType == ZMConversationTypeConnection || conversation.messages.count == 0) {
            conversation.lastReadEventID = conversation.lastEventID;
            conversation.lastReadServerTimeStamp = conversation.lastServerTimeStamp;
            [conversation setLocallyModifiedKeys:@[ZMConversationLastReadServerTimeStampKey].set];
        }
    }
}

+ (void)fetchAndDeleteConnectionRequestSystemMessagesInContext:(NSManagedObjectContext *)context
{
    NSPredicate *connectionPredicate = [NSPredicate predicateWithFormat:@"%K == %d",
                                        ZMMessageSystemMessageTypeKey, ZMSystemMessageTypeConnectionRequest];
    
    NSData *eventIDData = [ZMEventID eventIDWithMajor:2 minor:0].encodeToData;
    NSPredicate *firstAddUserPredicate = [NSPredicate predicateWithFormat:@"%K == %d AND %K < %@",
                                          ZMMessageSystemMessageTypeKey, ZMSystemMessageTypeParticipantsAdded,
                                          ZMMessageEventIDDataKey, eventIDData];
    
    NSPredicate *messagesToDeletePredicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[connectionPredicate, firstAddUserPredicate]];
    NSFetchRequest *fetchRequest = [ZMSystemMessage sortedFetchRequestWithPredicate:messagesToDeletePredicate];
    
    NSArray <ZMSystemMessage *>*messages = [context executeFetchRequestOrAssert:fetchRequest];

    for (ZMSystemMessage *systemMessage in messages) {
        [context deleteObject:systemMessage];
    }
    
    [context saveOrRollback];
}

+ (void)resetPushTokens
{
    [[NSNotificationCenter defaultCenter] postNotificationName:ZMUserSessionResetPushTokensNotificationName object:nil];
}

+ (void)removeSharingExtension
{
    NSURL *directoryURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[NSUserDefaults groupName]];
    if (directoryURL == nil) {
        ZMLogError(@"File url not valid");
        return;
    }
    
    NSURL *imageURL = [directoryURL URLByAppendingPathComponent:@"profile_images"];
    NSURL *conversationUrl = [directoryURL URLByAppendingPathComponent:@"conversations"];
    
    [[NSFileManager defaultManager] removeItemAtURL:imageURL error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:conversationUrl error:nil];
}


@end
