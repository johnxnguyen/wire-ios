//
// Wire
// Copyright (C) 2022 Wire Swiss GmbH
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
import WireSyncEngine

enum ShareableMediaSource: CaseIterable {
    case camera
    case photoLibrary
    case sketch
    case gif
    case audioRecording
    case shareExtension
    case clipboard
}

enum MediaShareRestrictionLevel {
    case none
    case securityFlag
    case APIFlag
}

final class MediaShareRestrictionManager {

    // MARK: - Private Properties

    private let sessionRestriction: SessionFileRestrictionsProtocol?
    private let securityFlagRestrictedTypes: [ShareableMediaSource] = [.photoLibrary,
                                                                        .gif,
                                                                        .shareExtension,
                                                                        .clipboard]

    // MARK: - Life cycle

    init(sessionRestriction: SessionFileRestrictionsProtocol?) {
        self.sessionRestriction = sessionRestriction
    }

    // MARK: - Public Properties

    var mediaShareRestrictionLevel: MediaShareRestrictionLevel {
        if let sessionRestriction = sessionRestriction, !sessionRestriction.isFileSharingEnabled {
            return .APIFlag
        }
        return SecurityFlags.fileSharing.isEnabled ? .none : .securityFlag
    }

    func canUploadMedia(from source: ShareableMediaSource) -> Bool {
        switch mediaShareRestrictionLevel {
        case .none:
            return true
        case .securityFlag:
            return !securityFlagRestrictedTypes.contains(source)
        case .APIFlag:
            return false
        }
    }

    var canDownloadMedia: Bool {
        switch mediaShareRestrictionLevel {
        case .none:
            return true
        case .APIFlag, .securityFlag:
            return false
        }
    }

    var canCopyFromClipboard: Bool {
        return canUploadMedia(from: .clipboard)
    }

    var hasAccessToCameraRoll: Bool {
        switch mediaShareRestrictionLevel {
        case .none:
            return true
        case .APIFlag, .securityFlag:
            return false
        }
    }

}
