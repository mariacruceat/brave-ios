// Copyright 2020 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import BraveUI
import Shared

/// Additonal information related to an action performed on a feed item
struct FeedItemActionContext {
    /// The feed item actioned upon
    var item: FeedItem
    /// The card that this item is displayed in
    var card: FeedCard
    /// The index path of the card in the collection view
    var indexPath: IndexPath
}

typealias FeedItemActionHandler = (FeedItemAction, _ context: FeedItemActionContext) -> Void

class BraveTodaySectionProvider: NSObject, NTPObservableSectionProvider {
    let dataSource: FeedDataSource
    var sectionDidChange: (() -> Void)?
    var actionHandler: FeedItemActionHandler
    
    init(dataSource: FeedDataSource, actionHandler: @escaping FeedItemActionHandler) {
        self.dataSource = dataSource
        self.actionHandler = actionHandler
        
        super.init()
        
        self.dataSource.load { [weak self] in
            self?.sectionDidChange?()
        }
    }
    
    @objc private func tappedBraveTodaySettings() {
        
    }
    
    func registerCells(to collectionView: UICollectionView) {
        collectionView.register(FeedCardCell<BraveTodayWelcomeView>.self)
        collectionView.register(FeedCardCell<HeadlineCardView>.self)
        collectionView.register(FeedCardCell<SmallHeadlinePairCardView>.self)
        collectionView.register(FeedCardCell<VerticalFeedGroupView>.self)
        collectionView.register(FeedCardCell<HorizontalFeedGroupView>.self)
        collectionView.register(FeedCardCell<NumberedFeedGroupView>.self)
        collectionView.register(FeedCardCell<SponsorCardView>.self)
    }
    
    var landscapeBehavior: NTPLandscapeSizingBehavior {
        .fullWidth
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.cards.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var size = fittingSizeForCollectionView(collectionView, section: indexPath.section)
        if indexPath.item == 0 {
            size.height = 300
        } else if let card = dataSource.cards[safe: indexPath.item - 1] {
            size.height = card.estimatedHeight(for: size.width)
        }
        return size
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item == 0 {
            return collectionView.dequeueReusableCell(for: indexPath) as FeedCardCell<BraveTodayWelcomeView>
        }
        
        guard let card = dataSource.cards[safe: indexPath.item - 1] else {
            assertionFailure()
            return UICollectionViewCell()
        }
        
        switch card {
        case .sponsor(let item):
            let cell = collectionView.dequeueReusableCell(for: indexPath) as FeedCardCell<SponsorCardView>
            cell.content.feedView.setupWithItem(item)
            cell.content.actionHandler = handler(for: item, card: card, indexPath: indexPath)
            cell.content.contextMenu = contextMenu(for: item, card: card, indexPath: indexPath)
            return cell
        case .headline(let item):
            let cell = collectionView.dequeueReusableCell(for: indexPath) as FeedCardCell<HeadlineCardView>
            cell.content.feedView.setupWithItem(item)
            cell.content.actionHandler = handler(for: item, card: card, indexPath: indexPath)
            cell.content.contextMenu = contextMenu(for: item, card: card, indexPath: indexPath)
            return cell
        case .headlinePair(let pair):
            let cell = collectionView.dequeueReusableCell(for: indexPath) as FeedCardCell<SmallHeadlinePairCardView>
            cell.content.smallHeadelineCardViews.left.feedView.setupWithItem(pair.first)
            cell.content.smallHeadelineCardViews.right.feedView.setupWithItem(pair.second)
            cell.content.actionHandler = handler(from: { $0 == 0 ? pair.first : pair.second }, card: card, indexPath: indexPath)
            cell.content.contextMenu = contextMenu(from: { $0 == 0 ? pair.first : pair.second }, card: card, indexPath: indexPath)
            return cell
        case .group(let items, let title, let direction, let displayBrand):
            let groupView: FeedGroupView
            let cell: UICollectionViewCell
            switch direction {
            case .horizontal:
                let horizontalCell = collectionView.dequeueReusableCell(for: indexPath) as FeedCardCell<HorizontalFeedGroupView>
                groupView = horizontalCell.content
                cell = horizontalCell
            case .vertical:
                let verticalCell = collectionView.dequeueReusableCell(for: indexPath) as FeedCardCell<VerticalFeedGroupView>
                groupView = verticalCell.content
                cell = verticalCell
            @unknown default:
                assertionFailure()
                return UICollectionViewCell()
            }
            groupView.titleLabel.text = title
            groupView.titleLabel.isHidden = title.isEmpty
            
            let isItemsAllSameSource = Set(items.map(\.content.publisherID)).count == 1
            
            zip(groupView.feedViews, items).forEach { (view, item) in
                view.setupWithItem(
                    item,
                    isBrandVisible: (isItemsAllSameSource && displayBrand) ? false : true
                )
            }
            if displayBrand {
                if let logo = items.first?.source.logo {
                    groupView.groupBrandImageView.sd_setImage(with: logo, placeholderImage: nil, options: .avoidAutoSetImage) { (image, _, cacheType, _) in
                        if cacheType == .none {
                            UIView.transition(
                                with: groupView.groupBrandImageView,
                                duration: 0.35,
                                options: [.transitionCrossDissolve, .curveEaseInOut],
                                animations: {
                                    groupView.groupBrandImageView.image = image
                            }
                            )
                        } else {
                            groupView.groupBrandImageView.image = image
                        }
                    }
                }
            } else {
                groupView.groupBrandImageView.image = nil
            }
            groupView.groupBrandImageView.isHidden = !displayBrand
            groupView.actionHandler = handler(from: { items[$0] }, card: card, indexPath: indexPath)
            groupView.contextMenu = contextMenu(from: { items[$0] }, card: card, indexPath: indexPath)
            return cell
        case .numbered(let items, let title):
            let cell = collectionView.dequeueReusableCell(for: indexPath) as FeedCardCell<NumberedFeedGroupView>
            cell.content.titleLabel.text = title
            zip(cell.content.feedViews, items).forEach { (view, item) in
                view.setupWithItem(item)
            }
            cell.content.actionHandler = handler(from: { items[$0] }, card: card, indexPath: indexPath)
            cell.content.contextMenu = contextMenu(from: { items[$0] }, card: card, indexPath: indexPath)
            return cell
        }
    }
    
    private func handler(from feedList: @escaping (Int) -> FeedItem, card: FeedCard, indexPath: IndexPath) -> (Int, FeedItemAction) -> Void {
        return { [weak self] index, action in
            self?.actionHandler(action, .init(item: feedList(index), card: card, indexPath: indexPath))
        }
    }
    
    private func handler(for item: FeedItem, card: FeedCard, indexPath: IndexPath) -> (Int, FeedItemAction) -> Void {
        return handler(from: { _ in item }, card: card, indexPath: indexPath)
    }
    
    private func contextMenu(from feedList: @escaping (Int) -> FeedItem, card: FeedCard, indexPath: IndexPath) -> FeedItemMenu {
        typealias MenuActionHandler = (_ context: FeedItemActionContext) -> Void
        
        let openInNewTabHandler: MenuActionHandler = { context in
            self.actionHandler(.opened(inNewTab: true), context)
        }
        let openInNewPrivateTabHandler: MenuActionHandler = { context in
            self.actionHandler(.opened(inNewTab: true, switchingToPrivateMode: true), context)
        }
        let hideHandler: MenuActionHandler = { context in
            self.actionHandler(.hide, context)
        }
        let blockSourceHandler: MenuActionHandler = { context in
            self.actionHandler(.blockSource, context)
        }
        
        if #available(iOS 13.0, *) {
            return .init { index -> UIMenu? in
                let item = feedList(index)
                let context = FeedItemActionContext(item: item, card: card, indexPath: indexPath)
                
                func mapDeferredHandler(_ handler: @escaping MenuActionHandler) -> UIActionHandler {
                    return UIAction.deferredActionHandler { _ in
                        handler(context)
                    }
                }
                
                var openInNewTab: UIAction {
                    .init(title: Strings.openNewTabButtonTitle, image: UIImage(named: "brave.plus"), handler: mapDeferredHandler(openInNewTabHandler))
                }
                
                var openInNewPrivateTab: UIAction {
                    .init(title: Strings.openNewPrivateTabButtonTitle, image: UIImage(named: "brave.shades"), handler: mapDeferredHandler(openInNewPrivateTabHandler))
                }
                
                var hideContent: UIAction {
                    // FIXME: Localize
                    .init(title: "Hide Content", image: UIImage(named: "hide.feed.item"), handler: mapDeferredHandler(hideHandler))
                }
                
                var blockSource: UIAction {
                    // FIXME: Localize
                    .init(title: "Block Source", image: UIImage(named: "block.feed.source"), attributes: .destructive, handler: mapDeferredHandler(blockSourceHandler))
                }
                
                let openActions: [UIAction] = [
                    openInNewTab,
                    // Brave Today is only available in normal tabs, so this isn't technically required
                    // but good to be on the safe side
                    !PrivateBrowsingManager.shared.isPrivateBrowsing ?
                        openInNewPrivateTab :
                    nil
                    ].compactMap({ $0 })
                let manageActions = [
                    hideContent,
                    blockSource
                ]
                
                var children: [UIMenu] = [
                    UIMenu(title: "", options: [.displayInline], children: openActions),
                ]
                if context.item.content.contentType == .article {
                    children.append(UIMenu(title: "", options: [.displayInline], children: manageActions))
                }
                return UIMenu(title: item.content.title, children: children)
            }
        }
        return .init { index -> FeedItemMenu.LegacyContext? in
            let item = feedList(index)
            let context = FeedItemActionContext(item: item, card: card, indexPath: indexPath)
            
            func mapHandler(_ handler: @escaping MenuActionHandler) -> UIAlertActionCallback {
                return { _ in
                    handler(context)
                }
            }
            
            var openInNewTab: UIAlertAction {
                .init(title: Strings.openNewTabButtonTitle, style: .default, handler: mapHandler(openInNewTabHandler))
            }
            
            var openInNewPrivateTab: UIAlertAction {
                .init(title: Strings.openNewPrivateTabButtonTitle, style: .default, handler: mapHandler(openInNewPrivateTabHandler))
            }
            
            var hideContent: UIAlertAction {
                // FIXME: Localize
                .init(title: "Hide Content", style: .default, handler: mapHandler(hideHandler))
            }
            
            var blockSource: UIAlertAction {
                // FIXME: Localize
                .init(title: "Block Source", style: .destructive, handler: mapHandler(blockSourceHandler))
            }
            
            let cancel = UIAlertAction(title: Strings.cancelButtonTitle, style: .cancel, handler: nil)
            
            var actions: [UIAlertAction?] = [
                openInNewTab,
                // Brave Today is only available in normal tabs, so this isn't technically required
                // but good to be on the safe side
                !PrivateBrowsingManager.shared.isPrivateBrowsing ?
                    openInNewPrivateTab :
                nil
            ]
            
            if context.item.content.contentType == .article {
                actions.append(contentsOf: [
                    hideContent,
                    blockSource
                ])
            }
            
            actions.append(cancel)
            
            return .init(
                title: item.content.title,
                message: nil,
                actions: actions.compactMap { $0 }
            )
        }
    }
    
    private func contextMenu(for item: FeedItem, card: FeedCard, indexPath: IndexPath) -> FeedItemMenu {
        return contextMenu(from: { _  in item }, card: card, indexPath: indexPath)
    }
}

extension FeedItemView {
    func setupWithItem(_ feedItem: FeedItem, isBrandVisible: Bool = true) {
        isContentHidden = feedItem.isContentHidden
        titleLabel.text = feedItem.content.title
        if #available(iOS 13, *) {
            dateLabel.text = RelativeDateTimeFormatter().localizedString(for: feedItem.content.publishTime, relativeTo: Date())
        }
        if feedItem.content.imageURL == nil {
            thumbnailImageView.isHidden = true
        } else {
            thumbnailImageView.isHidden = false
            thumbnailImageView.sd_setImage(with: feedItem.content.imageURL, placeholderImage: nil, options: .avoidAutoSetImage, completed: { (image, _, cacheType, _) in
                if cacheType == .none {
                    UIView.transition(
                        with: self.thumbnailImageView,
                        duration: 0.35,
                        options: [.transitionCrossDissolve, .curveEaseInOut],
                        animations: {
                            self.thumbnailImageView.image = image
                    }
                    )
                } else {
                    self.thumbnailImageView.image = image
                }
            })
        }
        brandContainerView.textLabel.text = nil
        brandContainerView.logoImageView.image = nil
        
        if isBrandVisible {
            brandContainerView.textLabel.text = feedItem.content.publisherName
            if let logo = feedItem.source.logo {
                brandContainerView.logoImageView.sd_setImage(with: logo, placeholderImage: nil, options: .avoidAutoSetImage) { (image, _, cacheType, _) in
                    if cacheType == .none {
                        UIView.transition(
                            with: self.brandContainerView.logoImageView,
                            duration: 0.35,
                            options: [.transitionCrossDissolve, .curveEaseInOut],
                            animations: {
                                self.brandContainerView.logoImageView.image = image
                        }
                        )
                    } else {
                        self.brandContainerView.logoImageView.image = image
                    }
                }
            }
        }
    }
}
