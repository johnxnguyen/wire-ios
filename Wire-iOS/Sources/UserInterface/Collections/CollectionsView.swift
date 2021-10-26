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
import UIKit

final class CollectionsView: UIView {
    var collectionViewLayout: CollectionViewLeftAlignedFlowLayout!
    var collectionView: UICollectionView!
    let noResultsView = NoResultsView()

    static let useAutolayout = false

    var noItemsInLibrary: Bool = false {
        didSet {
            noResultsView.isHidden = !noItemsInLibrary
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .from(scheme: .contentBackground)

        recreateLayout()
        collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: collectionViewLayout)

        collectionView.register(CollectionImageCell.self, forCellWithReuseIdentifier: CollectionImageCell.reuseIdentifier)
        collectionView.register(CollectionFileCell.self, forCellWithReuseIdentifier: CollectionFileCell.reuseIdentifier)
        collectionView.register(CollectionAudioCell.self, forCellWithReuseIdentifier: CollectionAudioCell.reuseIdentifier)
        collectionView.register(CollectionVideoCell.self, forCellWithReuseIdentifier: CollectionVideoCell.reuseIdentifier)
        collectionView.register(CollectionLinkCell.self, forCellWithReuseIdentifier: CollectionLinkCell.reuseIdentifier)
        collectionView.register(CollectionLoadingCell.self, forCellWithReuseIdentifier: CollectionLoadingCell.reuseIdentifier)
        collectionView.register(CollectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: CollectionHeaderView.reuseIdentifier)
        collectionView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.allowsMultipleSelection = false
        collectionView.allowsSelection = true
        collectionView.alwaysBounceVertical = true
        collectionView.isScrollEnabled = true
        collectionView.backgroundColor = UIColor.clear
        addSubview(collectionView)

        noResultsView.label.accessibilityLabel = "no items"
        noResultsView.label.text = "collections.section.no_items".localized(uppercased: true)
        noResultsView.icon = .library
        noResultsView.isHidden = true
        addSubview(noResultsView)
    }

    private func recreateLayout() {
        let layout = CollectionViewLeftAlignedFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 1
        layout.minimumInteritemSpacing = 1
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 8, right: 16)
        if CollectionsView.useAutolayout {
            layout.estimatedItemSize = CGSize(width: 64, height: 64)
        }

        collectionViewLayout = layout
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func closeButton() -> IconButton {
        let button = IconButton(style: .default)
        button.setIcon(.cross, size: .tiny, for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        button.accessibilityIdentifier = "close"
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -24)
        return button
    }

    static func backButton() -> IconButton {
        let button = IconButton(style: .default)
        button.setIcon(.backArrow, size: .tiny, for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 32, height: 20)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -16, bottom: 0, right: 0)
        button.accessibilityIdentifier = "back"
        return button
    }

    func constrainViews(searchViewController: TextSearchViewController) {
        addSubview(searchViewController.resultsView)
        addSubview(searchViewController.searchBar)

        if let searchBar = searchViewController.searchBar {
        [<#views#>].prepareForLayout()
        NSLayoutConstraint.activate([
          searchBar.topAnchor.constraint(equalTo: selfView.topAnchor),
          searchBar.leadingAnchor.constraint(equalTo: selfView.leadingAnchor),
          searchBar.trailingAnchor.constraint(equalTo: selfView.trailingAnchor),
          searchBar.heightAnchor.constraint(equalToConstant: 56),

          collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),

          collectionView.leadingAnchor.constraint(equalTo: selfView.leadingAnchor),
          collectionView.trailingAnchor.constraint(equalTo: selfView.trailingAnchor),
          collectionView.bottomAnchor.constraint(equalTo: selfView.bottomAnchor),

          noResultsView.topAnchor.constraint(greaterThanOrEqualTo: searchBar.bottomAnchor, constant: 12),
          noResultsView.centerXAnchor.constraint(equalTo: selfView.centerXAnchor),
          noResultsView.centerYAnchor.constraint(equalTo: selfView.centerYAnchor, constant: ~ UILayoutPriority.defaultLow),
          noResultsView.bottomAnchor.constraint(lessThanOrEqualTo: selfView.bottomAnchor, constant: -12),
          noResultsView.leadingAnchor.constraint(greaterThanOrEqualTo: selfView.leadingAnchor, constant: 24),
          noResultsView.trailingAnchor.constraint(lessThanOrEqualTo: selfView.trailingAnchor, constant: -24)
        ])
        }

        if let resultsView = searchViewController.resultsView {
        [<#views#>].prepareForLayout()
        NSLayoutConstraint.activate([
          resultsView.topAnchor.constraint(equalTo: collectionView.topAnchor),
          resultsView.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor),
          resultsView.leftAnchor.constraint(equalTo: collectionView.leftAnchor),
          resultsView.rightAnchor.constraint(equalTo: collectionView.rightAnchor)
        ])
        }
    }

}
