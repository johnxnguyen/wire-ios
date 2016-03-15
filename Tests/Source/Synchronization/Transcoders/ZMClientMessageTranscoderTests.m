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


@import ZMTransport;
@import ZMCMockTransport;
@import Cryptobox;
@import ZMProtos;

#import "ZMClientMessage.h"
#import "ZMClientMessageTranscoder+Internal.h"
#import "ZMMessageTranscoderTests.h"
#import "ZMClientMessage.h"
#import "ZMMessageTranscoder+Internal.h"
#import "NSManagedObjectContext+zmessaging.h"
#import "ZMUser+Internal.h"
#import "ZMConversation+Internal.h"
#import "ZMMessage+Internal.h"
#import "ZMSyncStrategy.h"
#import "ZMUpdateEvent.h"
#import "ZMUpstreamInsertedObjectSync.h"
#import "ZMUpstreamModifiedObjectSync.h"
#import "ZMMessageExpirationTimer.h"
#import "ZMUpstreamTranscoder.h"
#import "ZMChangeTrackerBootstrap+Testing.h"
#import "ZMAssetPreprocessingTracker.h"
#import "ZMAssetClientMessage.h"

#import "ZMLocalNotificationDispatcher.h"
#import <zmessaging/ZMUpstreamRequest.h>
#import <zmessaging/zmessaging-Swift.h>
#import "ZMAssetPreprocessingTracker.h"
#import "ZMContextChangeTracker.h"
#import "ZMAssetClientMessage+Testing.h"
#import "ZMNotifications.h"

@interface FakeClientMessageRequestFactory : NSObject

@end

@implementation FakeClientMessageRequestFactory

- (ZMTransportRequest *)upstreamRequestForAssetMessage:(ZMImageFormat __unused)format message:(ZMAssetClientMessage *__unused)message forConversationWithId:(NSUUID *__unused)conversationId
{
    return nil;
}


@end

@interface ZMClientMessageTranscoderTests : ZMMessageTranscoderTests

@property (nonatomic) ZMClientRegistrationStatus *mockClientRegistrationStatus;

@end



@implementation ZMClientMessageTranscoderTests

- (void)setUp
{
    [super setUp];
    self.mockClientRegistrationStatus = [OCMockObject mockForClass:ZMClientRegistrationStatus.class];
    self.sut = [ZMClientMessageTranscoder clientMessageTranscoderWithManagedObjectContext:self.syncMOC
                                                              localNotificationDispatcher:self.notificationDispatcher
                                                                 clientRegistrationStatus:self.mockClientRegistrationStatus];
    
    [[self.mockExpirationTimer stub] tearDown];
    [self verifyMockLater:self.mockClientRegistrationStatus];
}

- (void)tearDown
{
    [self.sut tearDown];
    self.sut = nil;
    [super tearDown];
}

- (UserClient *)insertMissingClientWithSelfClient:(UserClient *)selfClient;
{
    UserClient *missingClient = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
    missingClient.remoteIdentifier = [NSString createAlphanumericalString];
    missingClient.user = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
    [selfClient missesClient:missingClient];
    
    return missingClient;
}

- (ZMClientMessage *)insertMessageInConversation:(ZMConversation *)conversation
{
    NSString *messageText = @"foo";
    ZMGenericMessage *genericMessage = [ZMGenericMessage messageWithText:messageText nonce:[NSUUID createUUID].transportString];
    ZMClientMessage *message = [conversation appendClientMessageWithData:genericMessage.data];
    return message;
}


- (void)testThatItReturnsSelfClientAsDependentObjectForMessageIfItHasMissingClients
{
    //given
    UserClient *client = [self createSelfClient];
    UserClient *missingClient = [self insertMissingClientWithSelfClient:client];
    
    ZMConversation *conversation = [self insertGroupConversation];
    [conversation.mutableOtherActiveParticipants addObject:missingClient.user];
    [self.syncMOC saveOrRollback];
    
    ZMClientMessage *message = [self insertMessageInConversation:conversation];
    
    //when
    ZMManagedObject *dependentObject = [self.sut dependentObjectNeedingUpdateBeforeProcessingObject:message];
    
    // then
    XCTAssertNotNil(dependentObject);
    XCTAssertEqual(dependentObject, client);
}


- (void)testThatItReturnsConversationIfNeedsToBeUpdatedFromBackendBeforeMissingClients
{
    //given
    UserClient *client = [self createSelfClient];
    UserClient *missingClient = [self insertMissingClientWithSelfClient:client];
    
    ZMConversation *conversation = [self insertGroupConversation];
    [conversation.mutableOtherActiveParticipants addObject:missingClient.user];

    ZMClientMessage *message = [self insertMessageInConversation:conversation];
    
    // when
    conversation.needsToBeUpdatedFromBackend = YES;
    ZMManagedObject *dependentObject1 = [self.sut dependentObjectNeedingUpdateBeforeProcessingObject:message];
    
    // then
    XCTAssertNotNil(dependentObject1);
    XCTAssertEqual(dependentObject1, conversation);
}

- (void)testThatItReturnsConnectionIfNeedsToBeUpdatedFromBackendBeforeMissingClients
{
    //given
    UserClient *client = [self createSelfClient];
    UserClient *missingClient = [self insertMissingClientWithSelfClient:client];
    
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
    conversation.conversationType = ZMConversationTypeOneOnOne;
    conversation.connection = [ZMConnection insertNewObjectInManagedObjectContext:self.syncMOC];
    conversation.connection.to = missingClient.user;
    [conversation.mutableOtherActiveParticipants addObject:missingClient.user];
    
    ZMClientMessage *message = [self insertMessageInConversation:conversation];
    
    // when
    conversation.connection.needsToBeUpdatedFromBackend = YES;
    ZMManagedObject *dependentObject1 = [self.sut dependentObjectNeedingUpdateBeforeProcessingObject:message];
    
    // then
    XCTAssertNotNil(dependentObject1);
    XCTAssertEqual(dependentObject1, conversation.connection);
}


- (void)testThatItDoesNotReturnSelfClientAsDependentObjectForMessageIfConversationIsNotAffectedByMissingClients
{
    //given
    UserClient *client = [self createSelfClient];
    UserClient *missingClient = [self insertMissingClientWithSelfClient:client];

    
    ZMConversation *conversation1 = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
    [conversation1.mutableOtherActiveParticipants addObject:missingClient.user];
    
    ZMConversation *conversation2 = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
    conversation2.conversationType = ZMConversationTypeGroup;
    conversation2.remoteIdentifier = [NSUUID createUUID];
    
    ZMClientMessage *message = [self insertMessageInConversation:conversation2];

    // when
    ZMManagedObject *dependentObject = [self.sut dependentObjectNeedingUpdateBeforeProcessingObject:message];
    
    // then
    XCTAssertNil(dependentObject);
}

- (void)testThatItReturnsNilAsDependentObjectForMessageIfItHasNoMissingClients
{
    //given
    [self createSelfClient];
    
    ZMConversation *conversation = [self insertGroupConversation];
    ZMClientMessage *message = [self insertMessageInConversation:conversation];

    // when
    ZMManagedObject *dependentObject = [self.sut dependentObjectNeedingUpdateBeforeProcessingObject:message];
    
    // then
    XCTAssertNil(dependentObject);
}

- (void)testThatItReturnsAPreviousPendingTextMessageAsDependency
{
    //given
    [self createSelfClient];
    NSDate *zeroTime = [NSDate dateWithTimeIntervalSince1970:1000];
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    ZMTextMessage *message = [conversation appendMessagesWithText:@"message a1"].firstObject;
    message.nonce = [NSUUID createUUID];
    message.serverTimestamp = zeroTime;
    message.eventID = [self createEventID]; // already delivered message
    
    ZMTextMessage *nextMessage = [conversation appendMessagesWithText:@"message a2"].firstObject;
    nextMessage.serverTimestamp = [NSDate dateWithTimeInterval:100 sinceDate:zeroTime];
    nextMessage.nonce = [NSUUID createUUID]; // undelivered
    
    ZMGenericMessage *genericMessage = [ZMGenericMessage messageWithText:@"message a3" nonce:[NSUUID createUUID].transportString];
    ZMClientMessage *lastMessage = [conversation appendClientMessageWithData:genericMessage.data];
    lastMessage.serverTimestamp = [NSDate dateWithTimeInterval:10 sinceDate:nextMessage.serverTimestamp];
    
    // when
    XCTAssertTrue([self.syncMOC saveOrRollback]);
    
    // then
    ZMManagedObject *dependency = [self.sut dependentObjectNeedingUpdateBeforeProcessingObject:lastMessage];
    XCTAssertEqual(dependency, nextMessage);
}

- (void)testThatItGeneratesARequestToSendAClientMessage
{
    // given
    ZMConversation *conversation = [self insertGroupConversation];
    NSString *messageText = @"foo";
    ZMGenericMessage *genericMessage = [ZMGenericMessage messageWithText:messageText nonce:[NSUUID createUUID].transportString];
    
    ZMClientMessage *message = [conversation appendClientMessageWithData:genericMessage.data];
    XCTAssertTrue([self.uiMOC saveOrRollback]);

    // when
    ZMUpstreamRequest *request = [(id<ZMUpstreamTranscoder>) self.sut requestForInsertingObject:message forKeys:nil];
    
    // then
    //POST /conversations/{cnv}/messages
    NSString *expectedPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.remoteIdentifier.transportString, @"client-messages"]];
    NSDictionary *expectedPayload = @{@"content": message.genericMessage.data.base64String};
    
    XCTAssertNotNil(request);
    XCTAssertNotNil(request.transportRequest);
    XCTAssertEqualObjects(expectedPath, request.transportRequest.path);
    XCTAssertEqual(ZMMethodPOST, request.transportRequest.method);
    XCTAssertTrue([request.transportRequest.payload isKindOfClass:[NSDictionary class]]);
    XCTAssertEqualObjects(request.transportRequest.payload, expectedPayload);
}


- (void)testThatANewOtrMessageIsCreatedFromAnEvent
{
    [self.syncMOC performGroupedBlockAndWait:^{
        
        // given
        UserClient *client = [self createSelfClient];
        NSString *text = @"Everything";
        NSUUID *conversationID = [NSUUID createUUID];
        
        //create encrypted message
        ZMGenericMessage *message = [ZMGenericMessage messageWithText:text nonce:[NSUUID createUUID].transportString];
        NSError *error;
        CBSession *session = [client.keysStore.box sessionWithId:client.remoteIdentifier fromPreKey:[client.keysStore lastPreKeyAndReturnError:&error] error:&error];
        NSData *encryptedData = [session encrypt:message.data error:&error];
        
        NSDictionary *payload = @{@"recipient": client.remoteIdentifier, @"sender": client.remoteIdentifier, @"text": [encryptedData base64String]};
        ZMUpdateEvent *updateEvent = [ZMUpdateEvent eventFromEventStreamPayload:
                                      @{
                                        @"type":@"conversation.otr-message-add",
                                        @"data":payload,
                                        @"conversation":conversationID.transportString,
                                        @"time":[NSDate dateWithTimeIntervalSince1970:555555].transportString
                                    } uuid:nil];
        
        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        conversation.remoteIdentifier = conversationID;
        [self.syncMOC saveOrRollback];
        
        // when
        [self.sut processEvents:@[updateEvent] liveEvents:NO prefetchResult:nil];
        
        // then
        XCTAssertEqualObjects([conversation.messages.lastObject messageText], text);
    }];
}


- (void)testThatANewOtrMessageIsCreatedFromADecryptedAPNSEvent
{
    [self.syncMOC performGroupedBlockAndWait:^{
        // given
        UserClient *client = [self createSelfClient];
        NSString *text = @"Everything";
        NSUUID *conversationID = [NSUUID createUUID];
        
        //create encrypted message
        ZMGenericMessage *message = [ZMGenericMessage messageWithText:text nonce:[NSUUID createUUID].transportString];
        NSError *error;
        CBSession *session = [client.keysStore.box sessionWithId:client.remoteIdentifier fromPreKey:[client.keysStore lastPreKeyAndReturnError:&error] error:&error];
        NSData *encryptedData = [session encrypt:message.data error:&error];
        
        NSDictionary *payload = @{@"recipient": client.remoteIdentifier, @"sender": client.remoteIdentifier, @"text": [encryptedData base64String]};
        ZMUpdateEvent *updateEvent = [ZMUpdateEvent eventFromEventStreamPayload:
                                      @{
                                        @"type":@"conversation.otr-message-add",
                                        @"data":payload,
                                        @"conversation":conversationID.transportString,
                                        @"time":[NSDate dateWithTimeIntervalSince1970:555555].transportString
                                        } uuid:nil];
        
        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        conversation.remoteIdentifier = conversationID;
        [self.syncMOC saveOrRollback];
        ZMUpdateEvent *decryptedEvent = [client.keysStore.box decryptUpdateEventAndAddClient:updateEvent managedObjectContext:self.syncMOC];

        // when
        [self.sut processEvents:@[decryptedEvent] liveEvents:NO prefetchResult:nil];
        
        // then
        XCTAssertEqualObjects([conversation.messages.lastObject messageText], text);
    }];
}

- (void)testThatItReturnsTheDecryptedEventsAndRemovesEncryptedOneWhenDecryptEventsIsCalled
{
    XCTAssertTrue([self.sut respondsToSelector:@selector(decryptedUpdateEventsFromEvents:)]);
    
    [self.syncMOC performGroupedBlockAndWait:^{
        // given
        UserClient *client = [self createSelfClient];
        
        // create encrypted message
        NSError *error;
        ZMGenericMessage *message = [ZMGenericMessage messageWithText:@"Everything" nonce:NSUUID.createUUID.transportString];
        CBSession *session = [client.keysStore.box sessionWithId:client.remoteIdentifier fromPreKey:[client.keysStore lastPreKeyAndReturnError:&error] error:&error];
        NSData *encryptedData = [session encrypt:message.data error:&error];
        XCTAssertNil(error);
        
        NSDictionary *payload = @{ @"recipient" : client.remoteIdentifier, @"sender" : client.remoteIdentifier, @"text" : encryptedData.base64String };
        
        ZMUpdateEvent *safeEvent = [ZMUpdateEvent eventFromEventStreamPayload:@{
                                                                                @"type" : @"conversation.otr-message-add",
                                                                                @"data" : payload,
                                                                                @"conversation": NSUUID.createUUID.transportString,
                                                                                @"time" : [NSDate dateWithTimeIntervalSince1970:555555].transportString
                                                                                } uuid:nil];
        
        ZMUpdateEvent *unsafeEvent = [ZMUpdateEvent eventFromEventStreamPayload:@{
                                                                                  @"conversation" : NSUUID.createUUID.transportString,
                                                                                  @"time" : [NSDate dateWithTimeIntervalSince1970:1234000].transportString,
                                                                                  @"type" : @"conversation.message-add",
                                                                                  @"data" : @{ @"content" : @"fooo", @"nonce" : NSUUID.createUUID.transportString }
                                                                                  } uuid:nil];
        
        [self.syncMOC saveOrRollback];
        XCTAssertFalse(safeEvent.wasDecrypted);
        
        // when
        XCTAssertTrue([self.sut conformsToProtocol:@protocol(ZMUpdateEventDecryptor)]);
        NSArray <ZMUpdateEvent *>*updatedEvents = [(id <ZMUpdateEventDecryptor>)self.sut decryptedUpdateEventsFromEvents:@[safeEvent, unsafeEvent]];
        
        // then
        XCTAssertEqual(updatedEvents.count, 2lu);
        XCTAssertTrue(updatedEvents.firstObject.wasDecrypted);
        XCTAssertFalse([updatedEvents containsObject:safeEvent]);
        XCTAssertEqualObjects(updatedEvents.lastObject, unsafeEvent);
    }];
}

- (void)testThatItDecyptsTheEncryptedEventsWhileKeepingTheUnecryptedEventsAndReturnsTheNonceToPrefetchForUpdateEvents
{
    // given
    NSMutableArray <ZMUpdateEvent *>*events = [NSMutableArray array];
    UserClient *client = self.createSelfClient;
    
    for (ZMUpdateEventType type = 1; type < ZMUpdateEvent_LAST; type++) {
        if (type == ZMUpdateEventConversationClientMessageAdd ||
            type == ZMUpdateEventConversationOtrAssetAdd ||
            type == ZMUpdateEventConversationOtrMessageAdd) {
            continue;
        }
        
        NSString *eventTypeString = [ZMUpdateEvent eventTypeStringForUpdateEventType:type];
        NSUUID *nonce = NSUUID.createUUID;
        NSDictionary *payload = @{
                                  @"conversation" : NSUUID.createUUID.transportString,
                                  @"id" : self.createEventID.transportString,
                                  @"time" : [NSDate dateWithTimeIntervalSince1970:1234000].transportString,
                                  @"from" : NSUUID.createUUID.transportString,
                                  @"type" : eventTypeString,
                                  @"data" : @{
                                          @"content":@"fooo",
                                          @"nonce" : nonce.transportString,
                                          }
                                  };
        
        ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
        [events addObject:event];
    }
    
    NSUUID *otrNonce = NSUUID.createUUID;
    
    NSError *error;
    ZMGenericMessage *message = [ZMGenericMessage messageWithText:@"OTR message" nonce:otrNonce.transportString];
    CBPreKey *prekey = [client.keysStore lastPreKeyAndReturnError:&error];
    CBSession *session = [client.keysStore.box sessionWithId:client.remoteIdentifier fromPreKey:prekey error:&error];
    NSData *encryptedData = [session encrypt:message.data error:&error];
    XCTAssertNil(error);
    
    NSDictionary *payload = @{ @"recipient": client.remoteIdentifier, @"sender": client.remoteIdentifier, @"text": [encryptedData base64String] };
    ZMUpdateEvent *encryptedUpdateEvent = [ZMUpdateEvent eventFromEventStreamPayload: @{
                                                                               @"type" : @"conversation.otr-message-add",
                                                                               @"data" : payload,
                                                                               @"conversation" : NSUUID.createUUID.transportString,
                                                                               @"time" : [NSDate dateWithTimeIntervalSince1970:555555].transportString
                                                                               } uuid:nil];
    
    XCTAssertTrue([self.syncMOC saveOrRollback]);
    [events addObject:encryptedUpdateEvent];
    
    // when
    XCTAssertFalse([self.sut respondsToSelector:@selector(conversationRemoteIdentifiersToPrefetchToProcessEvents:)]);
    XCTAssertTrue([self.sut respondsToSelector:@selector(messageNoncesToPrefetchToProcessEvents:)]);
    XCTAssertTrue([self.sut conformsToProtocol:@protocol(ZMUpdateEventDecryptor)]);
    
    NSArray <ZMUpdateEvent *>*decryptedEvents = [(id <ZMUpdateEventDecryptor>)self.sut decryptedUpdateEventsFromEvents:events];
    
    // then
    XCTAssertEqual(decryptedEvents.count, 31lu);
    XCTAssertEqual(decryptedEvents.count, events.count);
    XCTAssertFalse([decryptedEvents containsObject:encryptedUpdateEvent]);
    XCTAssertTrue(decryptedEvents.lastObject.wasDecrypted);
    
    for (NSUInteger idx = 0; idx < decryptedEvents.count - 1; idx++) {
        XCTAssertFalse(decryptedEvents[idx].wasDecrypted);
    }
    
    for (NSUInteger idx = 0; idx < events.count; idx++) {
        XCTAssertFalse(events[idx].wasDecrypted);
    }
    
    NSSet <NSUUID *>*noncesToFetch = [self.sut messageNoncesToPrefetchToProcessEvents:decryptedEvents];
    
    // then
    XCTAssertTrue([noncesToFetch containsObject:otrNonce]);
    XCTAssertEqual(noncesToFetch.count, 1lu);
}

- (void)testThatItGeneratesARequestToSendAClientMessageWhenAMessageIsInsertedWithBlock:(void(^)(ZMMessage *message))block
{
    // given
    ZMConversation *conversation = [self insertGroupConversation];
    NSString *messageText = @"foo";
    
    ZMGenericMessage *genericMessage = [ZMGenericMessage messageWithText:messageText nonce:[NSUUID createUUID].transportString];
    
    ZMClientMessage *message = [conversation appendClientMessageWithData:genericMessage.data];
    XCTAssertTrue([self.uiMOC saveOrRollback]);
    WaitForAllGroupsToBeEmpty(0.5);
    
    // when
    block(message);
    ZMTransportRequest *request = [self.sut.requestGenerators nextRequest];
    
    // then
    //POST /conversations/{cnv}/messages
    NSString *expectedPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.remoteIdentifier.transportString, @"client-messages"]];
    XCTAssertNotNil(request);
    XCTAssertEqualObjects(expectedPath, request.path);
    XCTAssertEqualObjects(request.payload.asDictionary, @{@"content": message.genericMessage.data.base64String});
}

- (void)checkThatItGeneratesARequestToSendOTRMessageWhenAMessageIsInsertedWithBlock:(void(^)(ZMMessage *message))block
{
    // given
    ZMConversation *conversation = [self insertGroupConversation];
    NSString *messageText = @"foo";
    
    ZMClientMessage *message = [conversation appendOTRMessageWithText:messageText nonce:[NSUUID createUUID]];
    XCTAssertTrue([self.uiMOC saveOrRollback]);
    WaitForAllGroupsToBeEmpty(0.5);
    
    //self client
    conversation = [ZMConversation fetchObjectWithRemoteIdentifier:conversation.remoteIdentifier inManagedObjectContext:self.syncMOC];
    UserClient *selfClient = [self createSelfClient];
    
    //other user client
    NSError *error = nil;
    CBCryptoBox *otherClientsBox = [CBCryptoBox cryptoBoxWithPathURL:[UserClientKeysStore otrDirectory] error:&error];
    [conversation.otherActiveParticipants enumerateObjectsUsingBlock:^(ZMUser *user, NSUInteger idx, BOOL *__unused stop) {
        UserClient *userClient = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
        userClient.remoteIdentifier = [NSString createAlphanumericalString];
        userClient.user = user;
        
        NSError *keyError;
        CBPreKey *key = [otherClientsBox generatePreKeys:NSMakeRange(idx, 1) error:&keyError].firstObject;
        __unused CBSession *session = [selfClient.keysStore.box sessionWithId:userClient.remoteIdentifier fromPreKey:key error:&keyError];
    }];
    
    XCTAssertTrue([self.syncMOC saveOrRollback]);
    WaitForAllGroupsToBeEmpty(0.5);
    
    // when
    block(message);
    ZMTransportRequest *request = [self.sut.requestGenerators nextRequest];
    
    // then
    //POST /conversations/{cnv}/messages
    NSString *expectedPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.remoteIdentifier.transportString, @"otr", @"messages"]];
    XCTAssertNotNil(request);
    XCTAssertEqualObjects(expectedPath, request.path);
    
    ZMClientMessage *syncMessage = (ZMClientMessage *)[self.sut.managedObjectContext objectWithID:message.objectID];
    
    ZMNewOtrMessage *expectedOtrMessageMetadata = (ZMNewOtrMessage *)[[[ZMNewOtrMessage builder] mergeFromData: [syncMessage encryptedMessagePayloadData]] build];
    ZMNewOtrMessage *otrMessageMetadata = (ZMNewOtrMessage *)[[[ZMNewOtrMessage builder] mergeFromData:request.binaryData] build];
    
    [self assertNewOtrMessageMetadata:otrMessageMetadata expected:expectedOtrMessageMetadata conversation:conversation];
}

- (void)assertNewOtrMessageMetadata:(ZMNewOtrMessage *)otrMessageMetadata expected:(ZMNewOtrMessage *)expectedOtrMessageMetadata conversation:(ZMConversation *)conversation
{
    NSArray *userIds = [otrMessageMetadata.recipients mapWithBlock:^id(ZMUserEntry *entry) {
        return [[NSUUID alloc] initWithUUIDBytes:entry.user.uuid.bytes];
    }];
    
    NSArray *expectedUserIds = [expectedOtrMessageMetadata.recipients mapWithBlock:^id(ZMUserEntry *entry) {
        return [[NSUUID alloc] initWithUUIDBytes:entry.user.uuid.bytes];
    }];
    
    AssertArraysContainsSameObjects(userIds, expectedUserIds);
    
    NSArray *recipientsIds = [otrMessageMetadata.recipients flattenWithBlock:^NSArray *(ZMUserEntry *entry) {
        return [entry.clients mapWithBlock:^NSNumber *(ZMClientEntry *clientEntry) {
            return @(clientEntry.client.client);
        }];
    }];
    
    NSArray *expectedRecipientsIds = [expectedOtrMessageMetadata.recipients flattenWithBlock:^NSArray *(ZMUserEntry *entry) {
        return [entry.clients mapWithBlock:^NSNumber *(ZMClientEntry *clientEntry) {
            return @(clientEntry.client.client);
        }];
    }];
    
    AssertArraysContainsSameObjects(recipientsIds, expectedRecipientsIds);
    
    NSArray *conversationUserIds = [conversation.otherActiveParticipants.array mapWithBlock:^id(ZMUser *obj) {
        return [obj remoteIdentifier];
    }];
    AssertArraysContainsSameObjects(userIds, conversationUserIds);
    
    NSArray *conversationRecipientsIds = [conversation.otherActiveParticipants.array flattenWithBlock:^NSArray *(ZMUser *obj) {
        return [obj.clients.allObjects mapWithBlock:^NSString *(UserClient *client) {
            return client.remoteIdentifier;
        }];
    }];
    
    NSArray *stringRecipientsIds = [recipientsIds mapWithBlock:^NSString *(NSNumber *obj) {
        return [NSString stringWithFormat:@"%lx", (unsigned long)[obj unsignedIntegerValue]];
    }];
    
    AssertArraysContainsSameObjects(stringRecipientsIds, conversationRecipientsIds);
    
    XCTAssertEqual(otrMessageMetadata.nativePush, expectedOtrMessageMetadata.nativePush);
}

- (void)assertOtrAssetMetadata:(ZMOtrAssetMeta *)otrAssetMetadata expected:(ZMOtrAssetMeta *)expectedOtrAssetMetadata conversation:(ZMConversation *)conversation
{
    [self assertNewOtrMessageMetadata:(ZMNewOtrMessage *)otrAssetMetadata expected:(ZMNewOtrMessage *)expectedOtrAssetMetadata conversation:conversation];
    
    XCTAssertEqual(otrAssetMetadata.isInline, expectedOtrAssetMetadata.isInline);
}

- (void)testThatItGeneratesARequestToSendAMessageWhenAGenericMessageIsInserted_OnInitialization
{
    [self testThatItGeneratesARequestToSendAClientMessageWhenAMessageIsInsertedWithBlock:^(ZMMessage *message) {
        NOT_USED(message);
        [ZMChangeTrackerBootstrap bootStrapChangeTrackers:self.sut.contextChangeTrackers onContext:self.syncMOC];
    }];
}

- (void)testThatItGeneratesARequestToSendAMessageWhenAGenericMessageIsInserted_OnObjectsDidChange
{
    [self testThatItGeneratesARequestToSendAClientMessageWhenAMessageIsInsertedWithBlock:^(ZMMessage *message) {
        NOT_USED(message);
        [self.sut.contextChangeTrackers[0] objectsDidChange:[NSSet setWithObject:message]];
    }];
}

- (void)testThatItGeneratesARequestToSendAMessageWhenOTRMessageIsInserted_OnInitialization
{
    [self checkThatItGeneratesARequestToSendOTRMessageWhenAMessageIsInsertedWithBlock:^(ZMMessage *message) {
        NOT_USED(message);
        [ZMChangeTrackerBootstrap bootStrapChangeTrackers:self.sut.contextChangeTrackers onContext:self.syncMOC];
    }];
}

- (void)testThatItGeneratesARequestToSendAMessageWhenOTRMessageIsInserted_OnObjectsDidChange
{
    [self checkThatItGeneratesARequestToSendOTRMessageWhenAMessageIsInsertedWithBlock:^(ZMMessage *message) {
        NSManagedObject *syncMessage = [self.sut.managedObjectContext objectWithID:message.objectID];
        for(id changeTracker in self.sut.contextChangeTrackers) {
            [changeTracker objectsDidChange:[NSSet setWithObject:syncMessage]];
        }
    }];
}

- (ZMAssetClientMessage *)bootstrapAndCreateOTRAssetMessageInConversationWithId:(NSUUID *)conversationId
{
    ZMConversation *conversation = [self insertGroupConversationInMoc:self.syncMOC];
    conversation.remoteIdentifier = conversationId;
    return [self bootstrapAndCreateOTRAssetMessageInConversation:conversation];
}


- (ZMAssetClientMessage *)bootstrapAndCreateOTRAssetMessageInConversation:(ZMConversation *)conversation
{
    // given
    NSData *imageData = [self verySmallJPEGData];
    ZMAssetClientMessage *message = [self createImageMessageWithImageData:imageData format:ZMImageFormatMedium processed:YES stored:NO encrypted:YES moc:self.syncMOC];
    [conversation.mutableMessages addObject:message];
    XCTAssertTrue([self.syncMOC saveOrRollback]);
    
    //self client
    [self createSelfClient];
    
    //other user client
    [conversation.otherActiveParticipants enumerateObjectsUsingBlock:^(ZMUser *user, NSUInteger __unused idx, BOOL *__unused stop) {
        [self createClientForUser:user createSessionWithSelfUser:YES];
    }];
    
    XCTAssertTrue([self.syncMOC saveOrRollback]);
    return message;
}

- (void)prepareMessage:(ZMAssetClientMessage *)message ForUploadOnlyForFormat:(ZMImageFormat)format {
    
    // this will cause the message to be "ready to upload", but just for the given format
    ZMImageFormat otherFormat = format == ZMImageFormatMedium ? ZMImageFormatPreview : ZMImageFormatMedium;
    [message setImageData:message.originalImageData forFormat:format properties:[ZMIImageProperties imagePropertiesWithSize:message.originalImageSize length:1000 mimeType:@"image/jpg"]];
    [message setImageData:message.originalImageData forFormat:otherFormat properties:[ZMIImageProperties imagePropertiesWithSize:message.originalImageSize length:1000 mimeType:@"image/jpg"]];
    [message setNeedsToUploadFormat:format needsToUpload:YES];
    [message setNeedsToUploadFormat:otherFormat needsToUpload:NO];
    [self.syncMOC saveOrRollback];
    WaitForAllGroupsToBeEmpty(0.5);
}

- (void)testThatItGeneratesARequestToSendOTRAssetWhenAMessageIsInsertedWithFormat:(ZMImageFormat)format block:(void(^)(ZMMessage *message))block
{
    NSUUID *conversationId = [NSUUID createUUID];
    ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversationWithId:conversationId];
    [self prepareMessage:message ForUploadOnlyForFormat:format];
    
    // when
    block(message);
    WaitForAllGroupsToBeEmpty(0.5);
    ZMTransportRequest *request = [self.sut.requestGenerators nextRequest];
    
    // then
    //POST /conversations/{cnv}/otr/assets
    NSString *expectedPath = [NSString pathWithComponents:@[@"/", @"conversations", conversationId.transportString, @"otr", @"assets"]];
    XCTAssertNotNil(request);
    if(!request) {
        return;
    }
    XCTAssertEqualObjects(expectedPath, request.path);
    ZMMultipartBodyItem *metadataItem = [request multipartBodyItems].firstObject;

    ZMAssetClientMessage *syncMessage = (ZMAssetClientMessage *)[self.sut.managedObjectContext objectWithID:message.objectID];
    
    NSData *syncMessageData = [[syncMessage encryptedMessagePayloadForImageFormat:format] data];
    ZMOtrAssetMeta *expectedOtrMessageMetadata = (ZMOtrAssetMeta *)[[[ZMOtrAssetMeta builder] mergeFromData:syncMessageData] build];
    ZMOtrAssetMeta *otrMessageMetadata = (ZMOtrAssetMeta *)[[[ZMOtrAssetMeta builder] mergeFromData:metadataItem.data] build];

    [self assertOtrAssetMetadata:otrMessageMetadata expected:expectedOtrMessageMetadata conversation:message.conversation];
}

- (void)testThatItGeneratesARequestToSendAssetWhenOTRAssetIsInserted_OnInitialization
{
    [self testThatItGeneratesARequestToSendOTRAssetWhenAMessageIsInsertedWithFormat:ZMImageFormatMedium block:^(ZMMessage *message) {
        NOT_USED(message);
        [ZMChangeTrackerBootstrap bootStrapChangeTrackers:self.sut.contextChangeTrackers onContext:self.syncMOC];
    }];
}

- (void)testThatItGeneratesARequestToSendAssetWhenOTRAssetIsInserted_OnObjectsDidChange
{
    [self testThatItGeneratesARequestToSendOTRAssetWhenAMessageIsInsertedWithFormat:ZMImageFormatMedium block:^(ZMMessage *message) {
        NSManagedObject *syncMessage = [self.sut.managedObjectContext objectWithID:message.objectID];
        for(id changeTracker in self.sut.contextChangeTrackers) {
            [changeTracker objectsDidChange:[NSSet setWithObject:syncMessage]];
        }
    }];
}

- (ZMTransportRequest *)requestToDownloadAssetWithAssetId:(NSUUID *)assetId inConversationWithId:(NSUUID *)conversationId
{
    // given
    NSData *imageData = [self verySmallJPEGData];
    NSUUID *nonce = [NSUUID createUUID];
    
    ZMAssetClientMessage *message = [ZMAssetClientMessage assetClientMessageWithOriginalImageData:imageData
                                                                                            nonce:nonce
                                                                             managedObjectContext:self.syncMOC];
    message.isEncrypted = YES;
    
    ZMIImageProperties *properties = [ZMIImageProperties imagePropertiesWithSize:[ZMImagePreprocessor sizeOfPrerotatedImageWithData:imageData] length:imageData.length mimeType:@"image/jpeg"];
    ZMImageAssetEncryptionKeys *keys = [[ZMImageAssetEncryptionKeys alloc] initWithOtrKey:[NSData randomEncryptionKey] macKey:[NSData zmRandomSHA256Key] mac:[NSData zmRandomSHA256Key]];
    [message addGenericMessage:[ZMGenericMessage messageWithMediumImageProperties:properties processedImageProperties:properties encryptionKeys:keys nonce:nonce.transportString format:ZMImageFormatMedium]];
    [message addGenericMessage:[ZMGenericMessage messageWithMediumImageProperties:properties processedImageProperties:properties encryptionKeys:keys nonce:nonce.transportString format:ZMImageFormatPreview]];
    
    ZMConversation *conversation = [self insertGroupConversationInMoc:self.syncMOC];
    conversation.remoteIdentifier = conversationId;
    [conversation.mutableMessages addObject:message];
    
    XCTAssertTrue([self.syncMOC saveOrRollback]);
    WaitForAllGroupsToBeEmpty(0.5);
    
    [message resetLocallyModifiedKeys:[NSSet setWithObjects:ZMAssetClientMessage_NeedsToUploadPreviewKey, ZMAssetClientMessage_NeedsToUploadMediumKey, nil]];
    message.loadedMediumData = NO;
    
    message.assetId = assetId;

    for(id changeTracker in self.sut.contextChangeTrackers) {
        [changeTracker objectsDidChange:[NSSet setWithObject:message]];
    }
    
    ZMTransportRequest *request = [self.sut.requestGenerators nextRequest];
    return request;
}

- (void)testThatItReturnsRequestToDownloadAssetIfHasAssetId
{
    NSUUID *conversationId = [NSUUID createUUID];
    NSUUID *assetId = [NSUUID createUUID];
    ZMTransportRequest *request = [self requestToDownloadAssetWithAssetId:assetId inConversationWithId:conversationId];
    NSString *expectedPath = [NSString pathWithComponents:@[@"/", @"conversations", conversationId.transportString, @"otr", @"assets", assetId.transportString]];
    XCTAssertNotNil(request);
    if(!request) {
        return;
    }
    XCTAssertEqualObjects(request.path, expectedPath);
}

- (void)testThatItDoesNotReturnRequestToDownloadAssetIfItHasNoAssetId
{
    ZMTransportRequest *request = [self requestToDownloadAssetWithAssetId:nil inConversationWithId:[NSUUID createUUID]];
    XCTAssertNil(request);
}

- (void)testThatItUpdatesMessageWithImageData
{
    // given
    NSData *imageData = [self verySmallJPEGData];
    id message = [OCMockObject mockForClass:[ZMAssetClientMessage class]];
    ZMTransportResponse *response = [OCMockObject mockForClass:ZMTransportResponse.class];
    [[[(id)response stub] andReturn:imageData] rawData];
    [[[(id)response stub] andReturnValue:@(200)] HTTPStatus];
    
    //expect
    [[message expect] updateMessageWithImageData:imageData forFormat:ZMImageFormatMedium];
    
    // when
    [(ZMClientMessageTranscoder *)self.sut updateObject:message withResponse:response downstreamSync:nil];
    
    //then
    [message verify];
}

- (void)testThatItDeletesMessageIfDownstreamRequestFailed
{
    // given
    ZMAssetClientMessage *message = [ZMAssetClientMessage assetClientMessageWithOriginalImageData:nil
                                                                                            nonce:[NSUUID createUUID]
                                                                             managedObjectContext:self.syncMOC];
    
    // when
    [(ZMClientMessageTranscoder *)self.sut deleteObject:message downstreamSync:nil];
    
    // then
    XCTAssertTrue(message.isDeleted);

}

- (void)testThatItAddsMissingRecipientInMessageRelationship
{
    // given
    ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversationWithId:[NSUUID createUUID]];
    
    NSString *missingClientId = [NSString createAlphanumericalString];
    NSDictionary *payload = @{@"missing": @{[NSUUID createUUID].transportString : @[missingClientId]}};
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPstatus:412 transportSessionError:nil];
    
    // when
    [self.sut failedToUpdateInsertedObject:message request:nil response:response keysToParse:nil];
    
    // then
    UserClient *missingClient = message.missingRecipients.anyObject;
    XCTAssertNotNil(missingClient);
    XCTAssertEqualObjects(missingClient.remoteIdentifier, missingClientId);
}

- (void)testThatItDeletesTheCurrentClientIfWeGetA403ResponseWithCorrectLabel
{
    // given
    ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversationWithId:[NSUUID createUUID]];
    id <ZMTransportData> payload = @{ @"label": @"unknown-client" };
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPstatus:403 transportSessionError:nil];
    
    // expect
    [[(id)self.mockClientRegistrationStatus expect] didDetectCurrentClientDeletion];
    
    // when
    [self.sut failedToUpdateInsertedObject:message request:nil response:response keysToParse:nil];

    // then
    [(id)self.mockClientRegistrationStatus verify];
}

- (void)testThatItDoesNotDeletesTheCurrentClientIfWeGetA403ResponseWithoutTheCorrectLabel
{
    // given
    ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversationWithId:[NSUUID createUUID]];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:@[] HTTPstatus:403 transportSessionError:nil];
    
    // reject
    [[(id)self.mockClientRegistrationStatus reject] didDetectCurrentClientDeletion];
    
    // when
    [self.sut failedToUpdateInsertedObject:message request:nil response:response keysToParse:nil];
    
    // then
    [(id)self.mockClientRegistrationStatus verify];
}

- (void)testThatItSetsNeedsToBeUpdatedFromBackendOnConversationIfMissingMapIncludesUsersThatAreNoActiveUsers
{
    // given
    ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversationWithId:[NSUUID createUUID]];
    XCTAssertFalse(message.conversation.needsToBeUpdatedFromBackend);
    
    NSString *missingClientId = [NSString createAlphanumericalString];
    NSDictionary *payload = @{@"missing": @{[NSUUID createUUID].transportString : @[missingClientId]}};
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPstatus:412 transportSessionError:nil];
    
    // when
    [self.sut failedToUpdateInsertedObject:message request:nil response:response keysToParse:nil];
    
    // then
    XCTAssertTrue(message.conversation.needsToBeUpdatedFromBackend);
}

- (void)testThatItSetsNeedsToBeUpdatedFromBackendOnConnectionIfMissingMapIncludesUsersThatIsNoActiveUser_OneOnOne
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
    conversation.conversationType = ZMConversationTypeOneOnOne;
    conversation.remoteIdentifier = [NSUUID UUID];
    conversation.connection = [ZMConnection insertNewObjectInManagedObjectContext:self.syncMOC];
    ZMUser *user = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
    user.remoteIdentifier = [NSUUID UUID];
    
    ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversation:conversation];
    XCTAssertFalse(message.conversation.connection.needsToBeUpdatedFromBackend);
    
    NSString *missingClientId = [NSString createAlphanumericalString];
    NSDictionary *payload = @{@"missing": @{user.remoteIdentifier.transportString : @[missingClientId]}};
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPstatus:412 transportSessionError:nil];
    
    // when
    [self.sut failedToUpdateInsertedObject:message request:nil response:response keysToParse:nil];
    [self.syncMOC saveOrRollback];

    // then
    XCTAssertNotNil(user.connection);
    XCTAssertNotNil(message.conversation.connection);
    XCTAssertTrue(message.conversation.connection.needsToBeUpdatedFromBackend);
}

- (void)testThatItInsertsAndSetsNeedsToBeUpdatedFromBackendOnConnectionIfMissingMapIncludesUsersThatIsNoActiveUser_OneOnOne
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
    conversation.conversationType = ZMConversationTypeOneOnOne;
    conversation.remoteIdentifier = [NSUUID UUID];
    
    ZMUser *user = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
    user.remoteIdentifier = [NSUUID UUID];
    
    ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversation:conversation];
    XCTAssertFalse(message.conversation.needsToBeUpdatedFromBackend);
    
    NSString *missingClientId = [NSString createAlphanumericalString];
    NSDictionary *payload = @{@"missing": @{user.remoteIdentifier.transportString : @[missingClientId]}};
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPstatus:412 transportSessionError:nil];
    
    // when
    [self.sut failedToUpdateInsertedObject:message request:nil response:response keysToParse:nil];
    [self.syncMOC saveOrRollback];
    
    // then
    XCTAssertNotNil(user.connection);
    XCTAssertNotNil(message.conversation.connection);
    XCTAssertTrue(message.conversation.connection.needsToBeUpdatedFromBackend);
}
    
- (void)testThatItDeletesDeletedRecipientsOnFailure
{
    // given
    [self.syncMOC performGroupedBlockAndWait:^{
        UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
        client.remoteIdentifier = @"whoopy";
        client.user = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
        
        ZMUser *user = client.user;
        user.remoteIdentifier = [NSUUID createUUID];
        
        NSDictionary *payload = @{@"deleted": @{user.remoteIdentifier.transportString : @[client.remoteIdentifier]}};
        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPstatus:412 transportSessionError:nil];
        
        // when
        [self.sut failedToUpdateInsertedObject:nil request:nil response:response keysToParse:nil];
        [self.syncMOC saveOrRollback];
        
        // then
        XCTAssertTrue(client.isZombieObject);
        XCTAssertEqual(user.clients.count, 0u);
    }];
    WaitForAllGroupsToBeEmpty(0.5);

}

- (void)testThatItDeletesDeletedRecipientsOnSuccessInsertion
{
    [self.syncMOC performGroupedBlockAndWait:^{
        
        // given
        UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
        client.remoteIdentifier = @"whoopy";
        client.user = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
        
        ZMUser *user = client.user;
        user.remoteIdentifier = [NSUUID createUUID];
        
        NSDictionary *payload = @{@"deleted": @{user.remoteIdentifier.transportString : @[client.remoteIdentifier]}};
        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPstatus:200 transportSessionError:nil];
        
        // when
        [self.sut updateInsertedObject:nil request:nil response:response];
        [self.syncMOC saveOrRollback];
        
        // then
        XCTAssertTrue(client.isZombieObject);
        XCTAssertEqual(user.clients.count, 0u);
    }];
    
}

- (void)testThatItDeletesDeletedRecipientsOnSuccessUpdate
{
    [self.syncMOC performGroupedBlockAndWait:^{
        
        // given
        UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
        client.remoteIdentifier = @"whoopy";
        client.user = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
        
        ZMUser *user = client.user;
        user.remoteIdentifier = [NSUUID createUUID];
        
        NSDictionary *payload = @{@"deleted": @{user.remoteIdentifier.transportString : @[client.remoteIdentifier]}};
        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPstatus:200 transportSessionError:nil];
        
        // when
        [self.sut updateUpdatedObject:nil requestUserInfo:nil response:response keysToParse:nil];
        [self.syncMOC saveOrRollback];
        
        // then
        XCTAssertTrue(client.isZombieObject);
        XCTAssertEqual(user.clients.count, 0u);
    }];
    
}


- (void)checkThatItDeletesMessageIfFailedToCreatedUpdateRequestAndNoOriginalDataStored:(ZMImageFormat)format
{
    NSData *imageData = [self verySmallJPEGData];
    NSUUID *nonce = [NSUUID createUUID];
    ZMAssetClientMessage *message = [ZMAssetClientMessage assetClientMessageWithOriginalImageData:imageData nonce:nonce managedObjectContext:self.syncMOC];
    ZMIImageProperties *properties = [ZMIImageProperties imagePropertiesWithSize:[ZMImagePreprocessor sizeOfPrerotatedImageWithData:imageData] length:imageData.length mimeType:@""];
    [message addGenericMessage:[ZMGenericMessage messageWithMediumImageProperties:properties processedImageProperties:properties encryptionKeys:nil nonce:nonce.transportString format:format]];
    
    //when
    NSString *key;
    switch (format) {
        case ZMImageFormatPreview:
            key = ZMAssetClientMessage_NeedsToUploadPreviewKey;
            break;
        case ZMImageFormatMedium:
            key = ZMAssetClientMessage_NeedsToUploadMediumKey;
            break;
        default:
            break;
    }
    [self.sut requestForUpdatingObject:message forKeys:[NSSet setWithObject:key]];
    
    //then
    XCTAssertTrue(message.isDeleted);
}

- (void)testThatItDeletesMessageIfFailedToCreatedUpdateRequestForMediumFormatAndNoOriginalDataStored
{
    [self checkThatItDeletesMessageIfFailedToCreatedUpdateRequestAndNoOriginalDataStored:ZMImageFormatMedium];
}

- (void)testThatItDeletesMessageIfFailedToCreatedUpdateRequestForPreviewFormatAndNoOriginalDataStored
{
    [self checkThatItDeletesMessageIfFailedToCreatedUpdateRequestAndNoOriginalDataStored:ZMImageFormatPreview];
}

- (void)testThatItDoesNotSetTheAssetIdWhenParsingTheResponseForPreviewImage
{
    // given
    ZMAssetClientMessage *message = [ZMAssetClientMessage assetClientMessageWithOriginalImageData:[self verySmallJPEGData]
                                                                                            nonce:[NSUUID createUUID]
                                                                             managedObjectContext:self.syncMOC];
    NSDictionary *responsePayload = @{@"time" : [NSDate date].transportString};
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:responsePayload HTTPstatus:200 transportSessionError:nil];
    
    // when
    [self.sut updateUpdatedObject:message requestUserInfo:nil response:response keysToParse:[NSSet setWithObject:ZMAssetClientMessage_NeedsToUploadPreviewKey]];
    
    // then
    XCTAssertNil(message.assetId);
}


- (void)testThatItSetsTheAssetIdWhenParsingTheResponseForMediumImage
{
    // given
    ZMAssetClientMessage *message = [ZMAssetClientMessage assetClientMessageWithOriginalImageData:[self verySmallJPEGData]
                                                                                            nonce:[NSUUID createUUID]
                                                                             managedObjectContext:self.syncMOC];
    NSDictionary *responsePayload = @{@"time" : [NSDate date].transportString};
    NSUUID *assetID = [NSUUID createUUID];

    NSDictionary *responseHeader = @{@"Location" : assetID.transportString};
    ZMTransportResponse *response = [[ZMTransportResponse alloc] initWithPayload:responsePayload HTTPstatus:200 transportSessionError:nil headers:responseHeader];
    
    // when
    [self.sut updateUpdatedObject:message requestUserInfo:nil response:response keysToParse:[NSSet setWithObject:ZMAssetClientMessage_NeedsToUploadMediumKey]];
    
    // then
    XCTAssertEqualObjects(message.assetId, assetID);
}

@end


@implementation ZMClientMessageTranscoderTests (ClientsTrust)

- (NSArray *)createGroupConversationUsersWithClients
{
    self.selfUser = [ZMUser selfUserInContext:self.syncMOC];
    
    ZMUser *user1 = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
    UserClient *userClient1 = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
    ZMConnection *firstConnection = [ZMConnection insertNewSentConnectionToUser:user1];
    firstConnection.status = ZMConnectionStatusAccepted;
    userClient1.user = user1;
    
    ZMUser *user2 = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
    UserClient *userClient2 = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
    ZMConnection *secondConnection = [ZMConnection insertNewSentConnectionToUser:user2];
    secondConnection.status = ZMConnectionStatusAccepted;
    userClient2.user = user2;
    
    return @[user1, user2];
}

- (ZMMessage *)createMessageInGroupConversationWithUsers:(NSArray *)users encrypted:(BOOL)encrypted
{
    ZMClientMessage *message = [ZMClientMessage insertNewObjectInManagedObjectContext:self.syncMOC];
    message.isEncrypted = encrypted;
    
    ZMConversation *conversation = [ZMConversation insertGroupConversationIntoManagedObjectContext:self.syncMOC withParticipants:users];
    [conversation.mutableMessages addObject:message];
    return message;
}


@end



@implementation ZMClientMessageTranscoderTests (ZMLastRead)

- (void)testThatItPicksUpLastReadUpdateMessages
{
    // given
    [self.syncMOC performGroupedBlockAndWait:^{
        ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
        selfUser.remoteIdentifier = [NSUUID createUUID];
        ZMConversation *selfConversation = [ZMConversation conversationWithRemoteID:selfUser.remoteIdentifier createIfNeeded:YES inContext:self.syncMOC];
        selfConversation.conversationType = ZMConversationTypeSelf;
        
        NSDate *lastRead = [NSDate date];
        ZMConversation *updatedConversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        updatedConversation.remoteIdentifier = [NSUUID createUUID];
        updatedConversation.lastReadServerTimeStamp = lastRead;
        
        ZMClientMessage *lastReadUpdateMessage = [ZMConversation appendSelfConversationWithLastReadOfConversation:updatedConversation];
        XCTAssertNotNil(lastReadUpdateMessage);

        // when
        for (id tracker in self.sut.contextChangeTrackers) {
            [tracker objectsDidChange:[NSSet setWithObject:lastReadUpdateMessage]];
        }
    }];
    
    WaitForAllGroupsToBeEmpty(0.5);
    
    [self.syncMOC performGroupedBlockAndWait:^{
        ZMTransportRequest *request = [self.sut.requestGenerators.firstObject nextRequest];
        
        // then
        XCTAssertNotNil(request);
    }];
    WaitForAllGroupsToBeEmpty(0.5);
}

- (void)testThatItCreatesARequestForLastReadUpdateMessages
{
    // given
    [self.syncMOC performGroupedBlockAndWait:^{
        ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
        selfUser.remoteIdentifier = [NSUUID createUUID];
        ZMConversation *selfConversation = [ZMConversation conversationWithRemoteID:selfUser.remoteIdentifier createIfNeeded:YES inContext:self.syncMOC];
        selfConversation.conversationType = ZMConversationTypeSelf;

        NSDate *lastRead = [NSDate date];
        ZMConversation *updatedConversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        updatedConversation.remoteIdentifier = [NSUUID createUUID];
        updatedConversation.lastReadServerTimeStamp = lastRead;
        
        ZMClientMessage *lastReadUpdateMessage = [ZMConversation appendSelfConversationWithLastReadOfConversation:updatedConversation];
        XCTAssertNotNil(lastReadUpdateMessage);
        [[self.mockExpirationTimer stub] stopTimerForMessage:lastReadUpdateMessage];
        
        // when
        ZMUpstreamRequest *request = [(id<ZMUpstreamTranscoder>)self.sut requestForInsertingObject:lastReadUpdateMessage forKeys:nil];
        
        // then
        XCTAssertNotNil(request);
    }];
    WaitForAllGroupsToBeEmpty(0.5);
}


@end


@implementation ZMClientMessageTranscoderTests (GenericMessageData)

- (void)testThatThePreviewGenericMessageDataHasTheOriginalSizeOfTheMediumGenericMessagedata
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
    ZMAssetClientMessage *message = [conversation appendOTRMessageWithImageData:[self dataForResource:@"1900x1500_medium" extension:@"jpg"] nonce:[NSUUID createUUID]];
    [[(id)self.upstreamObjectSync stub] objectsDidChange:OCMOCK_ANY];
    [[(id)self.mockExpirationTimer stub] objectsDidChange:OCMOCK_ANY];
    // when
    for(id<ZMContextChangeTracker> tracker in self.sut.contextChangeTrackers) {
        [tracker objectsDidChange:[NSSet setWithObject:message]];
    }
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    ZMGenericMessage *mediumGenericMessage = [message genericMessageForFormat:ZMImageFormatMedium];
    ZMGenericMessage *previewGenericMessage = [message genericMessageForFormat:ZMImageFormatPreview];
    
    XCTAssertEqual(mediumGenericMessage.image.height, previewGenericMessage.image.originalHeight);
    XCTAssertEqual(mediumGenericMessage.image.width, previewGenericMessage.image.originalWidth);
}

@end
