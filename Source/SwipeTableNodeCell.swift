//
//  SwipeTableNodeCell.swift
//  SwipeCellKit
//
//  Created by Moustoifa Moumini on 12/02/2020.
//

import Foundation
import AsyncDisplayKit
/**
The `SwipeTableNodeCell` class extends `ASCellNode` and provides more flexible options for cell swiping behavior.


The default behavior closely matches the stock Mail.app. If you want to customize the transition style (ie. how the action buttons are exposed), or the expansion style (the behavior when the row is swiped passes a defined threshold), you can return the appropriately configured `SwipeOptions` via the `SwipeTableViewCellDelegate` delegate.
*/

open class SwipeTableNodeCell: ASCellNode {
    
    /// The object that acts as the delegate of the `SwipeTableNodeCell`.
    public weak var delegate: SwipeScrollViewCellDelegate?
    
    public var state = SwipeState.center
    var actionsView: SwipeActionsView?
    var scrollView: UIScrollView? {
        return tableView ?? collectionView
    }

    var panGestureRecognizer: UIGestureRecognizer
    {
        return swipeController.panGestureRecognizer;
    }
    
    var swipeController: SwipeController!
    var isPreviouslySelected = false
    
    weak var tableView: UITableView?
    weak var collectionView: UICollectionView?

    
    /// :nodoc:
    open override var frame: CGRect {
        set { super.frame = state.isActive ? CGRect(origin: CGPoint(x: frame.minX, y: newValue.minY), size: newValue.size) : newValue }
        get { return super.frame }
    }
    
    /// :nodoc:
    open override var layoutMargins: UIEdgeInsets {
        get {
            return frame.origin.x != 0 ? swipeController.originalLayoutMargins : super.layoutMargins
        }
        set {
            super.layoutMargins = newValue
        }
    }
    
    /// :nodoc:
    public override init() {
        super.init()
    }

    
    deinit {
        scrollView?.panGestureRecognizer.removeTarget(self, action: nil)
    }
    
    func configure() {
        clipsToBounds = false

        swipeController = SwipeController(swipeableNode: self, actionsContainerView: self.view)
        swipeController.delegate = self
    }
    
    
    /// :nodoc:
    override open func didEnterDisplayState() {
        super.didEnterDisplayState()
        configure()
        var view: UIView = self.view
        while let superview = view.superview?.superview?.superview {
            view = superview

            if let tableView = view as? UITableView {
                self.tableView = tableView

                swipeController.scrollView = tableView;
                
                tableView.panGestureRecognizer.removeTarget(self, action: nil)
                tableView.panGestureRecognizer.addTarget(self, action: #selector(handleTablePan(gesture:)))
                return
            }
            if let collectionView = view as? UICollectionView {
                self.collectionView = collectionView

                swipeController.scrollView = collectionView;
                
                collectionView.panGestureRecognizer.removeTarget(self, action: nil)
                collectionView.panGestureRecognizer.addTarget(self, action: #selector(handleTablePan(gesture:)))
                return
            }
        }
    }
    
    /// :nodoc:
  /*  override open func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        if editing {
            hideSwipe(animated: false)
        }
    }*/
    
    // Override so we can accept touches anywhere within the cell's minY/maxY.
    // This is required to detect touches on the `SwipeActionsView` sitting alongside the
    // `SwipeTableCell`.
    /// :nodoc:
    override open func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let superview = view.superview?.superview else { return false }
        
        let point = view.convert(point, to: superview)

        if !UIAccessibility.isVoiceOverRunning {
            for cell in tableView?.swipeCells ?? [] {
                if (cell.state == .left || cell.state == .right) && !cell.contains(point: point) {
                    tableView?.hideSwipeCell()
                    return false
                }
            }
            for cell in collectionView?.swipeCells ?? [] {
                if (cell.state == .left || cell.state == .right) && !cell.contains(point: point) {
                    collectionView?.hideSwipeCell()
                    return false
                }
            }
        }
        
        return contains(point: point)
    }
    
    func contains(point: CGPoint) -> Bool {
        return point.y > frame.minY && point.y < frame.maxY
    }
    
    /// :nodoc:
    
    /// :nodoc:
    override open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return swipeController.gestureRecognizerShouldBegin(gestureRecognizer)
    }
    /*
    /// :nodoc:
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        swipeController.traitCollectionDidChange(from: previousTraitCollection, to: self.traitCollection)
    }
    */
    @objc func handleTablePan(gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            hideSwipe(animated: true)
        }
    }
    
    func reset() {
        swipeController.reset()
        clipsToBounds = false
    }
    
    func resetSelectedState() {
        if isPreviouslySelected {
            if let tableView = tableView, let indexPath = self.indexPath {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
            if let collectionView = collectionView, let indexPath = self.indexPath {
                collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
            }
        }
        isPreviouslySelected = false
    }
}

extension SwipeTableNodeCell: SwipeControllerDelegate {
    func swipeController(_ controller: SwipeController, canBeginEditingSwipeableFor orientation: SwipeActionsOrientation) -> Bool {
        if let cell = self.view.superview?.superview as? UITableViewCell {
            return cell.isEditing == false
        }
        return true
    }
    
    func swipeController(_ controller: SwipeController, editActionsForSwipeableFor orientation: SwipeActionsOrientation) -> [SwipeAction]? {
        guard let scrollView = scrollView, let indexPath = self.indexPath else { return nil }
        
        return delegate?.scrollView(scrollView, editActionsForRowAt: indexPath, for: orientation)
    }
    
    func swipeController(_ controller: SwipeController, editActionsOptionsForSwipeableFor orientation: SwipeActionsOrientation) -> SwipeOptions {
        guard let scrollView = scrollView, let indexPath = self.indexPath else { return SwipeOptions() }
        
        return delegate?.scrollView(scrollView, editActionsOptionsForRowAt: indexPath, for: orientation) ?? SwipeOptions()
    }
    
    func swipeController(_ controller: SwipeController, visibleRectFor scrollView: UIScrollView) -> CGRect? {


        return delegate?.visibleRect(for: scrollView)
    }
    
    func swipeController(_ controller: SwipeController, willBeginEditingSwipeableFor orientation: SwipeActionsOrientation) {
        guard let scrollView = scrollView, let indexPath = self.indexPath else { return }

        // Remove highlight and deselect any selected cells
        isHighlighted = false
        isPreviouslySelected = isSelected
        tableView?.deselectRow(at: indexPath, animated: false)
        collectionView?.deselectItem(at: indexPath, animated: false)

        delegate?.scrollView(scrollView, willBeginEditingRowAt: indexPath, for: orientation)
    }
    
    func swipeController(_ controller: SwipeController, didEndEditingSwipeableFor orientation: SwipeActionsOrientation) {
        guard let scrollView = scrollView, let indexPath = self.indexPath, let actionsView = self.actionsView else { return }
        
        resetSelectedState()
        
        delegate?.scrollView(scrollView, didEndEditingRowAt: indexPath, for: actionsView.orientation)
    }
    
    func swipeController(_ controller: SwipeController, didDeleteSwipeableAt indexPath: IndexPath) {
        tableView?.deleteRows(at: [indexPath], with: .none)
        collectionView?.deleteItems(at: [indexPath])

    }
}
