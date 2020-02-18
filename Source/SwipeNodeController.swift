//
//  SwipeNodeController.swift
//  SwipeCellKit
//
//  Created by Moustoifa moumini on 18/02/2020.
//

import Foundation
import AsyncDisplayKit

class SwipeNodeController: SwipeController {
    
    weak var swipeableNode: (ASDisplayNode & Swipeable)?
    weak var actionsContainerViewNode: UIView?{
        swipeableNode?.view
    }
    
    init(swipeable: ASDisplayNode & Swipeable) {
        self.swipeableNode = swipeable
        super.init()
        
        configure()
    }
    
    @objc override func handlePan(gesture: UIPanGestureRecognizer) {
        guard let target = actionsContainerViewNode, var swipeable = self.swipeableNode else { return }
        
        let velocity = gesture.velocity(in: target)
        
        if delegate?.swipeController(self, canBeginEditingSwipeableFor: velocity.x > 0 ? .left : .right) == false {
            return
        }
        
        switch gesture.state {
        case .began:
            if let swipeable = scrollView?.swipeables.first(where: { $0.state == .dragging }) as? UIView, self.swipeableNode != nil, swipeable != self.swipeableNode! {
                return
            }
            
            stopAnimatorIfNeeded()
            
            originalCenter = target.center.x
            
            if swipeable.state == .center || swipeable.state == .animatingToCenter {
                let orientation: SwipeActionsOrientation = velocity.x > 0 ? .left : .right
                
                showActionsView(for: orientation)
            }
        case .changed:
            guard let actionsView = swipeable.actionsView, let actionsContainerView = self.actionsContainerViewNode else { return }
            guard swipeable.state.isActive else { return }
            
            if swipeable.state == .animatingToCenter {
                let swipedCell = scrollView?.swipeables.first(where: { $0.state == .dragging || $0.state == .left || $0.state == .right }) as? UIView
                if let swipedCell = swipedCell, self.swipeableNode != nil, swipedCell != self.swipeableNode! {
                    return
                }
            }
            
            let translation = gesture.translation(in: target).x
            scrollRatio = 1.0
            
            // Check if dragging past the center of the opposite direction of action view, if so
            // then we need to apply elasticity
            if (translation + originalCenter - swipeable.bounds.midX) * actionsView.orientation.scale > 0 {
                target.center.x = gesture.elasticTranslation(in: target,
                                                             withLimit: .zero,
                                                             fromOriginalCenter: CGPoint(x: originalCenter, y: 0)).x
                swipeable.actionsView?.visibleWidth = abs((swipeable as Swipeable).frame.minX)
                scrollRatio = elasticScrollRatio
                return
            }
            
            if let expansionStyle = actionsView.options.expansionStyle, let scrollView = scrollView {
                
                let referenceFrame = actionsContainerView != swipeable ? actionsContainerView.frame : nil;
                let expanded = expansionStyle.shouldExpand(view: swipeable, gesture: gesture, in: scrollView, within: referenceFrame)
                let targetOffset = expansionStyle.targetOffset(for: swipeable)
                let currentOffset = abs(translation + originalCenter - swipeable.bounds.midX)
                
                if expanded && !actionsView.expanded && targetOffset > currentOffset {
                    let centerForTranslationToEdge = swipeable.bounds.midX - targetOffset * actionsView.orientation.scale
                    let delta = centerForTranslationToEdge - originalCenter
                    
                    animate(toOffset: centerForTranslationToEdge)
                    gesture.setTranslation(CGPoint(x: delta, y: 0), in: swipeable.view.superview!)
                } else {
                    target.center.x = gesture.elasticTranslation(in: target,
                                                                 withLimit: CGSize(width: targetOffset, height: 0),
                                                                 fromOriginalCenter: CGPoint(x: originalCenter, y: 0),
                                                                 applyingRatio: expansionStyle.targetOverscrollElasticity).x
                    swipeable.actionsView?.visibleWidth = abs(actionsContainerView.frame.minX)
                }
                
                actionsView.setExpanded(expanded: expanded, feedback: true)
            } else {
                target.center.x = gesture.elasticTranslation(in: target,
                                                             withLimit: CGSize(width: actionsView.preferredWidth, height: 0),
                                                             fromOriginalCenter: CGPoint(x: originalCenter, y: 0),
                                                             applyingRatio: elasticScrollRatio).x
                swipeable.actionsView?.visibleWidth = abs(actionsContainerView.frame.minX)
                
                if (target.center.x - originalCenter) / translation != 1.0 {
                    scrollRatio = elasticScrollRatio
                }
            }
        case .ended, .cancelled, .failed:
            guard let actionsView = swipeable.actionsView, let actionsContainerView = self.actionsContainerViewNode else { return }
            if swipeable.state.isActive == false && swipeable.bounds.midX == target.center.x  {
                return
            }
            
            swipeable.state = targetState(forVelocity: velocity)
            
            if actionsView.expanded == true, let expandedAction = actionsView.expandableAction  {
                perform(action: expandedAction)
            } else {
                let targetOffset = targetCenter(active: swipeable.state.isActive)
                let distance = targetOffset - actionsContainerView.center.x
                let normalizedVelocity = velocity.x * scrollRatio / distance
                
                animate(toOffset: targetOffset, withInitialVelocity: normalizedVelocity) { _ in
                    if self.swipeableNode?.state == .center {
                        self.reset()
                    }
                }
                
                if !swipeable.state.isActive {
                    delegate?.swipeController(self, didEndEditingSwipeableFor: actionsView.orientation)
                }
            }
        default: break
        }
    }
    
    @discardableResult
    override func showActionsView(for orientation: SwipeActionsOrientation) -> Bool {
        
        guard let actions = delegate?.swipeController(self, editActionsForSwipeableFor: orientation), actions.count > 0 else { return false }
        
        guard let swipeable = self.swipeableNode else { return false }
        
        originalLayoutMargins = swipeable.layoutMargins
        
        configureActionsView(with: actions, for: orientation)
        
        delegate?.swipeController(self, willBeginEditingSwipeableFor: orientation)
        
        return true
    }
    
    override func configureActionsView(with actions: [SwipeAction], for orientation: SwipeActionsOrientation) {
        guard var swipeable = self.swipeableNode,
            let actionsContainerView = self.actionsContainerViewNode,
            let scrollView = self.scrollView else {
                return
        }
        
        let options = delegate?.swipeController(self, editActionsOptionsForSwipeableFor: orientation) ?? SwipeOptions()
        
        swipeable.actionsView?.removeFromSuperview()
        swipeable.actionsView = nil
        
        var contentEdgeInsets = UIEdgeInsets.zero
        if let visibleTableViewRect = delegate?.swipeController(self, visibleRectFor: scrollView) {
            
            let frame = (swipeable as Swipeable).frame
            let visibleSwipeableRect = frame.intersection(visibleTableViewRect)
            if visibleSwipeableRect.isNull == false {
                let top = visibleSwipeableRect.minY > frame.minY ? max(0, visibleSwipeableRect.minY - frame.minY) : 0
                let bottom = max(0, frame.size.height - visibleSwipeableRect.size.height - top)
                contentEdgeInsets = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
            }
        }
        
        let actionsView = SwipeActionsView(contentEdgeInsets: contentEdgeInsets,
                                           maxSize: swipeable.bounds.size,
                                           safeAreaInsetView: scrollView,
                                           options: options,
                                           orientation: orientation,
                                           actions: actions)
        actionsView.delegate = self
        
        actionsContainerView.addSubview(actionsView)
        
        actionsView.heightAnchor.constraint(equalTo: swipeable.view.heightAnchor).isActive = true
        actionsView.widthAnchor.constraint(equalTo: swipeable.view.widthAnchor, multiplier: 2).isActive = true
        actionsView.topAnchor.constraint(equalTo: swipeable.view.topAnchor).isActive = true
        
        if orientation == .left {
            actionsView.rightAnchor.constraint(equalTo: actionsContainerView.leftAnchor).isActive = true
        } else {
            actionsView.leftAnchor.constraint(equalTo: actionsContainerView.rightAnchor).isActive = true
        }
        
        actionsView.setNeedsUpdateConstraints()
        
        swipeable.actionsView = actionsView
        
        swipeable.state = .dragging
    }
    
    override func animate(duration: Double = 0.7, toOffset offset: CGFloat, withInitialVelocity velocity: CGFloat = 0, completion: ((Bool) -> Void)? = nil) {
        stopAnimatorIfNeeded()
        
        swipeableNode?.layoutIfNeeded()
        
        let animator: SwipeAnimator = {
            if velocity != 0 {
                if #available(iOS 10, *) {
                    let velocity = CGVector(dx: velocity, dy: velocity)
                    let parameters = UISpringTimingParameters(mass: 1.0, stiffness: 100, damping: 18, initialVelocity: velocity)
                    return UIViewPropertyAnimator(duration: 0.0, timingParameters: parameters)
                } else {
                    return UIViewSpringAnimator(duration: duration, damping: 1.0, initialVelocity: velocity)
                }
            } else {
                if #available(iOS 10, *) {
                    return UIViewPropertyAnimator(duration: duration, dampingRatio: 1.0)
                } else {
                    return UIViewSpringAnimator(duration: duration, damping: 1.0)
                }
            }
        }()
        
        animator.addAnimations({
            guard let swipeable = self.swipeableNode, let actionsContainerView = self.actionsContainerViewNode else { return }
            
            actionsContainerView.center = CGPoint(x: offset, y: actionsContainerView.center.y)
            swipeable.actionsView?.visibleWidth = abs(actionsContainerView.frame.minX)
            swipeable.layoutIfNeeded()
        })
        
        if let completion = completion {
            animator.addCompletion(completion: completion)
        }
        
        self.animator = animator
        
        animator.startAnimation()
    }
    
    override func traitCollectionDidChange(from previousTraitCollrection: UITraitCollection?, to traitCollection: UITraitCollection) {
        guard let swipeable = self.swipeableNode,
            let actionsContainerView = self.actionsContainerViewNode,
            previousTraitCollrection != nil else {
                return
        }
        
        if swipeable.state == .left || swipeable.state == .right {
            let targetOffset = targetCenter(active: swipeable.state.isActive)
            actionsContainerView.center = CGPoint(x: targetOffset, y: actionsContainerView.center.y)
            swipeable.actionsView?.visibleWidth = abs(actionsContainerView.frame.minX)
            swipeable.layoutIfNeeded()
        }
    }
    
    
    
    override func targetState(forVelocity velocity: CGPoint) -> SwipeState {
        guard let actionsView = swipeableNode?.actionsView else { return .center }
        
        switch actionsView.orientation {
        case .left:
            return (velocity.x < 0 && !actionsView.expanded) ? .center : .left
        case .right:
            return (velocity.x > 0 && !actionsView.expanded) ? .center : .right
        }
    }
    
    override func targetCenter(active: Bool) -> CGFloat {
        guard let swipeable = self.swipeableNode else { return 0 }
        guard let actionsView = swipeable.actionsView, active == true else { return swipeable.bounds.midX }
        
        return swipeable.bounds.midX - actionsView.preferredWidth * actionsView.orientation.scale
    }
    
    override func configure() {
        swipeableNode?.view.addGestureRecognizer(tapGestureRecognizer)
        swipeableNode?.view.addGestureRecognizer(panGestureRecognizer)
    }
    
    override func reset() {
        swipeableNode?.state = .center
        
        swipeableNode?.actionsView?.removeFromSuperview()
        swipeableNode?.actionsView = nil
    }
    
    
    override func perform(action: SwipeAction) {
        guard let actionsView = swipeableNode?.actionsView else { return }
        
        if action == actionsView.expandableAction, let expansionStyle = actionsView.options.expansionStyle {
            // Trigger the expansion (may already be expanded from drag)
            actionsView.setExpanded(expanded: true)
            
            switch expansionStyle.completionAnimation {
            case .bounce:
                perform(action: action, hide: true)
            case .fill(let fillOption):
                performFillAction(action: action, fillOption: fillOption)
            }
        } else {
            perform(action: action, hide: action.hidesWhenSelected)
        }
    }
    
    override func perform(action: SwipeAction, hide: Bool) {
        guard let indexPath = swipeableNode?.indexPath else { return }
        
        if hide {
            hideSwipe(animated: true)
        }
        
        action.handler?(action, indexPath)
    }
    
    override func performFillAction(action: SwipeAction, fillOption: SwipeExpansionStyle.FillOptions) {
        guard let swipeable = self.swipeableNode, let actionsContainerView = self.actionsContainerViewNode else { return }
        guard let actionsView = swipeable.actionsView, let indexPath = swipeable.indexPath else { return }
        
        let newCenter = swipeable.bounds.midX - (swipeable.bounds.width + actionsView.minimumButtonWidth) * actionsView.orientation.scale
        
        action.completionHandler = { [weak self] style in
            guard let `self` = self else { return }
            action.completionHandler = nil
            
            self.delegate?.swipeController(self, didEndEditingSwipeableFor: actionsView.orientation)
            
            switch style {
            case .delete:
                actionsContainerView.mask = actionsView.createDeletionMask()
                
                self.delegate?.swipeController(self, didDeleteSwipeableAt: indexPath)
                
                UIView.animate(withDuration: 0.3, animations: {
                    guard let actionsContainerView = self.actionsContainerViewNode else { return }
                    
                    actionsContainerView.center.x = newCenter
                    actionsContainerView.mask?.frame.size.height = 0
                    swipeable.actionsView?.visibleWidth = abs(actionsContainerView.frame.minX)
                    
                    if fillOption.timing == .after {
                        actionsView.alpha = 0
                    }
                }) { [weak self] _ in
                    self?.actionsContainerViewNode?.mask = nil
                    self?.resetSwipe()
                    self?.reset()
                }
            case .reset:
                self.hideSwipe(animated: true)
            }
        }
        
        let invokeAction = {
            action.handler?(action, indexPath)
            
            if let style = fillOption.autoFulFillmentStyle {
                action.fulfill(with: style)
            }
        }
        
        animate(duration: 0.3, toOffset: newCenter) { _ in
            if fillOption.timing == .after {
                invokeAction()
            }
        }
        
        if fillOption.timing == .with {
            invokeAction()
        }
    }
    
    override func hideSwipe(animated: Bool, completion: ((Bool) -> Void)? = nil) {
        guard var swipeable = self.swipeableNode, let actionsContainerView = self.actionsContainerViewNode else { return }
        guard swipeable.state == .left || swipeable.state == .right else { return }
        guard let actionView = swipeable.actionsView else { return }
        
        swipeable.state = .animatingToCenter
        
        let targetCenter = self.targetCenter(active: false)
        
        if animated {
            animate(toOffset: targetCenter) { complete in
                self.reset()
                completion?(complete)
            }
        } else {
            actionsContainerView.center = CGPoint(x: targetCenter, y: actionsContainerView.center.y)
            swipeable.actionsView?.visibleWidth = abs(actionsContainerView.frame.minX)
            reset()
        }
        
        delegate?.swipeController(self, didEndEditingSwipeableFor: actionView.orientation)
    }
    
    @objc override func resetSwipe() {
        guard let swipeable = self.swipeableNode, let actionsContainerView = self.actionsContainerViewNode else { return }
        
        let targetCenter = self.targetCenter(active: false)
        
        actionsContainerView.center = CGPoint(x: targetCenter, y: actionsContainerView.center.y)
        swipeable.actionsView?.visibleWidth = abs(actionsContainerView.frame.minX)
    }
    
    
    override func setSwipeOffset(_ offset: CGFloat, animated: Bool = true, completion: ((Bool) -> Void)? = nil) {
        guard var swipeable = self.swipeableNode, let actionsContainerView = self.actionsContainerViewNode else { return }
        
        guard offset != 0 else {
            hideSwipe(animated: animated, completion: completion)
            return
        }
        
        let orientation: SwipeActionsOrientation = offset > 0 ? .left : .right
        let targetState = SwipeState(orientation: orientation)
        
        if swipeable.state != targetState {
            guard showActionsView(for: orientation) else { return }
            
            scrollView?.hideSwipeables()
            
            swipeable.state = targetState
        }
        
        let maxOffset = min(swipeable.bounds.width, abs(offset)) * orientation.scale * -1
        let targetCenter = abs(offset) == CGFloat.greatestFiniteMagnitude ? self.targetCenter(active: true) : swipeable.bounds.midX + maxOffset
        
        if animated {
            animate(toOffset: targetCenter) { complete in
                completion?(complete)
            }
        } else {
            actionsContainerView.center.x = targetCenter
            swipeable.actionsView?.visibleWidth = abs(actionsContainerView.frame.minX)
        }
    }
}
