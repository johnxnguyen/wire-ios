//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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

import XCTest
@testable import Wire

final class SettingsClientViewControllerTests: ZMSnapshotTestCase, CoreDataFixtureTestHelper {
    var coreDataFixture: CoreDataFixture!

    var sut: SettingsClientViewController!
    var client: UserClient!

    override func setUp() {
        super.setUp()
        coreDataFixture = CoreDataFixture()

        let otherYearFormatter =  WRDateFormatter.otherYearFormatter

        XCTAssertEqual(otherYearFormatter.locale.identifier, "en_US", "otherYearFormatter.locale.identifier is \(otherYearFormatter.locale.identifier)")

        client = mockUserClient()
    }

    override func tearDown() {
        sut = nil
        client = nil

        coreDataFixture = nil

        super.tearDown()
    }

    func prepareSut(variant: ColorSchemeVariant?) {
        sut = SettingsClientViewController(userClient: client, variant: variant)

        sut.isLoadingViewVisible = false
    }

    func testForTransparentBackground() {
        prepareSut(variant: nil)

        verify(matching: sut)
    }

    func testForLightTheme() {
        prepareSut(variant: .light)

        verify(matching: sut)
    }

    func testForDarkTheme() {
        prepareSut(variant: .dark)

        verify(matching: sut)
    }

    func testForLightThemeWrappedInNavigationController() {
        prepareSut(variant: .light)
        let navWrapperController = sut.wrapInNavigationController()

        verify(matching: navWrapperController)
    }
}
