//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
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

import UIKit

final class ConversationCellBurstTimestampView: UIView {

    let unreadDot = UIView()
    private let label: UILabel = UILabel()

    var separatorColor: UIColor?
    var separatorColorExpanded: UIColor?

    private let unreadDotContainer = UIView()
    private let leftSeparator = UIView()
    private let rightSeparator = UIView()

    private let inset: CGFloat = 16
    private let unreadDotHeight: CGFloat = 8
    private var heightConstraints = [NSLayoutConstraint]()
    private var accentColorObserver: AccentColorChangeHandler?
    private let burstNormalFont = UIFont.smallLightFont
    private let burstBoldFont = UIFont.smallSemiboldFont

    private var isShowingUnreadDot: Bool = true {
        didSet {
            leftSeparator.isHidden = isShowingUnreadDot
            unreadDot.isHidden = !isShowingUnreadDot
        }
    }

    private var isSeparatorHidden: Bool = false {
        didSet {
            leftSeparator.isHidden = isSeparatorHidden || isShowingUnreadDot
            rightSeparator.isHidden = isSeparatorHidden
        }
    }

    private var isSeparatorExpanded: Bool = false {
        didSet {
            separatorHeight = isSeparatorExpanded ? 4 : .hairline
            let color = isSeparatorExpanded ? separatorColorExpanded : separatorColor
            leftSeparator.backgroundColor = color
            rightSeparator.backgroundColor = color
        }
    }

    private var separatorHeight: CGFloat = .hairline {
        didSet {
            heightConstraints.forEach {
                $0.constant = separatorHeight
            }
        }
    }

    init() {
        super.init(frame: .zero)
        setupViews()
        createConstraints()

        accentColorObserver = AccentColorChangeHandler.addObserver(self) { [weak self] (color, _) in
            self?.unreadDot.backgroundColor = color
        }

        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        [leftSeparator, label, rightSeparator, unreadDotContainer].forEach(addSubview)
        unreadDotContainer.addSubview(unreadDot)

        unreadDotContainer.backgroundColor = .clear
        unreadDot.backgroundColor = .accent()
        unreadDot.layer.cornerRadius = unreadDotHeight / 2
        clipsToBounds = true
    }

    private func createConstraints() {

        [self,
         label,
         leftSeparator,
         rightSeparator,
         unreadDotContainer,
         unreadDot].prepareForLayout()

        heightConstraints = [
            leftSeparator.heightAnchor.constraint(equalToConstant: separatorHeight),
            rightSeparator.heightAnchor.constraint(equalToConstant: separatorHeight)
        ]

        NSLayoutConstraint.activate(heightConstraints + [
            heightAnchor.constraint(equalToConstant: 40),

            leftSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            leftSeparator.widthAnchor.constraint(equalToConstant: conversationHorizontalMargins.left - inset),
            leftSeparator.centerYAnchor.constraint(equalTo: centerYAnchor),

            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: leftSeparator.trailingAnchor, constant: inset),

            rightSeparator.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: inset),
            rightSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
            rightSeparator.centerYAnchor.constraint(equalTo: centerYAnchor),

            unreadDotContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            unreadDotContainer.trailingAnchor.constraint(equalTo: label.leadingAnchor),
            unreadDotContainer.topAnchor.constraint(equalTo: topAnchor),
            unreadDotContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            unreadDot.centerXAnchor.constraint(equalTo: unreadDotContainer.centerXAnchor),
            unreadDot.centerYAnchor.constraint(equalTo: unreadDotContainer.centerYAnchor),
            unreadDot.heightAnchor.constraint(equalToConstant: unreadDotHeight),
            unreadDot.widthAnchor.constraint(equalToConstant: unreadDotHeight)
        ])
    }

    func setupStyle() {
        label.textColor = UIColor.from(scheme: .textForeground)
        separatorColor = UIColor.from(scheme: .separator)
        separatorColorExpanded = UIColor.from(scheme: .paleSeparator)
    }

    func configure(with timestamp: Date, includeDayOfWeek: Bool, showUnreadDot: Bool) {
        if includeDayOfWeek {
            isSeparatorExpanded = true
            isSeparatorHidden = false
            label.font = burstBoldFont
            label.text = timestamp.olderThanOneWeekdateFormatter.string(from: timestamp).localizedUppercase
        } else {
            isSeparatorExpanded = false
            isSeparatorHidden = false
            label.font = burstNormalFont
            label.text = timestamp.formattedDate.localizedUppercase
        }

        isShowingUnreadDot = showUnreadDot
    }

    func prepareForReuse() {
        label.text = nil
    }
}
