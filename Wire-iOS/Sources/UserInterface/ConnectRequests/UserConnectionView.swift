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
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation
import WireDataModel
import UIKit
import WireSyncEngine

final class UserConnectionView: UIView, Copyable {

    public convenience init(instance: UserConnectionView) {
        self.init(user: instance.user)
    }

    static private var correlationFormatter: AddressBookCorrelationFormatter = {
        return AddressBookCorrelationFormatter(
            lightFont: FontSpec(.small, .light).font!,
            boldFont: FontSpec(.small, .medium).font!,
            color: UIColor.from(scheme: .textDimmed)
        )
    }()

    private let firstLabel = UILabel()
    private let secondLabel = UILabel()
    private let labelContainer = UIView()
    private let userImageView = UserImageView()

    public var user: UserType {
        didSet {
            updateLabels()
            userImageView.user = user
        }
    }

    public init(user: UserType) {
        self.user = user
        super.init(frame: .zero)
        userImageView.userSession = ZMUserSession.shared()
        setup()
        createConstraints()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        [firstLabel, secondLabel].forEach {
            $0.numberOfLines = 0
            $0.textAlignment = .center
        }

        userImageView.accessibilityLabel = "user image"
        userImageView.size = .big
        userImageView.user = user

        [labelContainer, userImageView].forEach(addSubview)
        [firstLabel, secondLabel].forEach(labelContainer.addSubview)
        updateLabels()
    }

    private func updateLabels() {
        updateFirstLabel()
        updateSecondLabel()
    }

    private func updateFirstLabel() {
        if let handleText = handleLabelText {
            firstLabel.attributedText = handleText
            firstLabel.accessibilityIdentifier = "username"
        } else {
            firstLabel.attributedText = correlationLabelText
            firstLabel.accessibilityIdentifier = "correlation"
        }
    }

    private func updateSecondLabel() {
        guard nil != handleLabelText else { return }
        secondLabel.attributedText = correlationLabelText
        secondLabel.accessibilityIdentifier = "correlation"
    }

    private var handleLabelText: NSAttributedString? {
        guard let handle = user.handle, handle.count > 0 else { return nil }
        return ("@" + handle) && [
            .foregroundColor: UIColor.from(scheme: .textDimmed),
            .font: FontSpec(.small, .semibold).font!
        ]
    }

    private var correlationLabelText: NSAttributedString? {
        return type(of: self).correlationFormatter.correlationText(
            for: user,
            addressBookName: (user as? ZMUser)?.addressBookEntry?.cachedName
        )
    }

    private func createConstraints() {
        [<#views#>].prepareForLayout()
        NSLayoutConstraint.activate([
          labelContainer.centerXAnchor.constraint(equalTo: selfView.centerXAnchor),
          labelContainer.topAnchor.constraint(equalTo: selfView.topAnchor),
          labelContainer.leftAnchor.constraint(greaterThanOrEqualTo: selfView.leftAnchor),

          userImageView.topAnchor.constraint(greaterThanOrEqualTo: labelContainer.bottomAnchor),
          userImageView.centerXAnchor.constraint(equalTo: selfView.centerXAnchor),
          userImageView.centerYAnchor.constraint(equalTo: selfView.centerYAnchor),
          userImageView.leftAnchor.constraint(greaterThanOrEqualTo: selfView.leftAnchor, constant: 54),
          userImageView.widthAnchor.constraint(equalTo: userImageView.heightAnchor),
          userImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 264),
          userImageView.bottomAnchor.constraint(lessThanOrEqualTo: selfView.bottomAnchor)
        ])

        let verticalMargin = CGFloat(16)

        [<#views#>].prepareForLayout()
        NSLayoutConstraint.activate([
          handleLabel.topAnchor.constraint(equalTo: labelContainer.topAnchor, constant: verticalMargin),
          handleLabel.heightAnchor.constraint(equalToConstant: 16),
          correlationLabel.topAnchor.constraint(equalTo: handleLabel.bottomAnchor),
          handleLabel.heightAnchor.constraint(equalToConstant: 16),
          correlationLabel.bottomAnchor.constraint(equalTo: labelContainer.bottomAnchor, constant: -verticalMargin),

          [handleLabel, correlationLabel].forEach {,
          $0.leadingAnchor.constraint(equalTo: labelContainer.leadingAnchor),
          $0.trailingAnchor.constraint(equalTo: labelContainer.trailingAnchor)
        ])
        }
    }

}
