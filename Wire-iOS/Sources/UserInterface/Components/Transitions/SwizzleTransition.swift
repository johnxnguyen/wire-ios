// 
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
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

enum SwizzleTransitionDirection {
    case horizontal
    case vertical
}

final class SwizzleTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let direction: SwizzleTransitionDirection

    init(direction: SwizzleTransitionDirection) {
        self.direction = direction
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.5
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toView = transitionContext.toView,
              let fromView = transitionContext.fromView else {
            return
        }
        let containerView = transitionContext.containerView

        containerView.addSubview(toView)

        if !transitionContext.isAnimated {
            transitionContext.completeTransition(true)
            return
        }
        containerView.setNeedsLayout()

        let durationPhase1: TimeInterval
        let durationPhase2: TimeInterval
        if direction == .horizontal {
            toView.layer.transform = CATransform3DMakeTranslation(24, 0, 0)
            durationPhase1 = 0.15
            durationPhase2 = 0.55
        } else {
            toView.layer.transform = CATransform3DMakeTranslation(0, 48, 0)
            durationPhase1 = 0.10
            durationPhase2 = 0.30
        }
        toView.alpha = 0

        UIView.animate(easing: .easeInQuad, duration: durationPhase1, animations: {
            fromView.alpha = 0
            fromView.layer.transform = self.direction == .horizontal ? CATransform3DMakeTranslation(48, 0, 0) : CATransform3DMakeTranslation(0, 48, 0)
        }) { finished in
            UIView.animate(easing: .easeOutQuad, duration: durationPhase2, animations: {
                toView.layer.transform = CATransform3DIdentity
                toView.alpha = 1
            }) { finished in
                fromView.layer.transform = CATransform3DIdentity
                transitionContext.completeTransition(true)
            }
        }
    }
}
