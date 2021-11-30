//
// Wire
// Copyright (C) 2021 Wire Swiss GmbH
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
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation
import WireDataModel

extension AnalyticsEvent {

    static func initiatedCall(asVideoCall: Bool, in conversation: ZMConversation) -> AnalyticsEvent {
        var event = AnalyticsEvent(name: "calling.initiated_call")
        event.attributes = conversation.analyticsAttributes
        event.attributes[.startedAsVideoCall] = asVideoCall
        return event
    }

    static func joinedCall(asVideoCall: Bool, callDirection: CallDirection, in conversation: ZMConversation) -> AnalyticsEvent {
        var event = AnalyticsEvent(name: "calling.joined_call")
        event.attributes = conversation.analyticsAttributes
        event.attributes[.startedAsVideoCall] = asVideoCall
        event.attributes[.callDirection] = callDirection
        return event
    }

    static func establishedCall(asVideoCall: Bool, in conversation: ZMConversation) -> AnalyticsEvent {
        var event = AnalyticsEvent(name: "calling.established_call")
        event.attributes = conversation.analyticsAttributes
        event.attributes[.startedAsVideoCall] = asVideoCall
        return event
    }

    static func screenShare(callDirection: CallDirection, duration: Double, in conversation: ZMConversation) -> AnalyticsEvent {
        var event = AnalyticsEvent(name: "calling.screen_share")
        event.attributes = conversation.analyticsAttributes
        event.attributes[.callDirection] = callDirection
        event.attributes[.screenShareDuration] =  RoundedInt(Int(duration), factor: 6)
        return event
    }

    enum CallDirection: String, AnalyticsAttributeValue {

        case incoming
        case outgoing

        var analyticsValue: String {
            return rawValue
        }
    }

}

private extension AnalyticsAttributeKey {

    /// Whether a call started as a video call.
    ///
    /// Expected to refer to a value of type `Boolean`.
    static let startedAsVideoCall = AnalyticsAttributeKey(rawValue: "call_video")

    /// The direction of the call.
    ///
    /// Expected to refer to a value of type `AnalyticsCallDirectionType`.
    static let callDirection  = AnalyticsAttributeKey(rawValue: "call_direction")

    /// The duration of the screen-sharing.
    ///
    /// Expected to refer to a value of type `RoundedInt`.
    static let screenShareDuration = AnalyticsAttributeKey(rawValue: "screen_share_duration")

}
