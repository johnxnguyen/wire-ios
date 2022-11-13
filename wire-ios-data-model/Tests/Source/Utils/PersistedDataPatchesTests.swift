//
//  PersistedDataPatchesTests.swift
//  WireDataModel
//
//  Created by John Ranjith on 11/13/22.
//  Copyright © 2022 Wire Swiss GmbH. All rights reserved.
//

import Foundation
import XCTest
@testable import WireDataModel


// MARK: - Test patches
class PersistedDataPatchesTests: ZMBaseManagedObjectTest {

    func testThatItApplyPatchesWhenPreviousVersionIsLesser() {

        // GIVEN
        var patchApplied = false
        let patch = PersistedDataPatch(version: 3) { (moc) in
            XCTAssertEqual(moc, self.syncMOC)
            patchApplied = true
        }
        // this will bump last patched version to current version
        self.syncMOC.performGroupedBlockAndWait {
            PersistedDataPatch.applyAll(in: self.syncMOC, patches: [])
        }

        // WHEN
        self.syncMOC.performGroupedBlockAndWait {
            PersistedDataPatch.applyAll(in: self.syncMOC, patches: [patch])
        }

        // THEN
        XCTAssertTrue(patchApplied)
    }
    
    func testThatItDoesNotApplyPatchesWhenPreviousVersionIsGreaterThanCurrentVersion() {

        // GIVEN
        var patchApplied = false
        let patch = PersistedDataPatch(version: 2) { (_) in
            XCTFail()
            patchApplied = true
        }
        // this will bump last patched version to current version, which is greater than 0.0.1
        self.syncMOC.performGroupedBlockAndWait {
            PersistedDataPatch.applyAll(in: self.syncMOC, patches: [])
        }

        // WHEN
        self.syncMOC.performGroupedBlockAndWait {
            PersistedDataPatch.applyAll(in: self.syncMOC, patches: [patch])
        }

        // THEN
        XCTAssertFalse(patchApplied, "Version: \(Bundle(for: ZMUser.self).infoDictionary!["CFBundleShortVersionString"] as! String)")
    }
}

