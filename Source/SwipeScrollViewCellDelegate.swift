//
//  SwipeScrollViewCellDelegate.swift
//  SwipeCellKit
//
//  Created by Moustoifa Moumini on 13/02/2020.
//

import UIKit

public protocol SwipeScrollViewCellDelegate: class {
    
    /**
     Asks the delegate for the actions to display in response to a swipe in the specified row.
     
     - parameter scrollView: The table view or collection View object which owns the cell requesting this information.
     
     - parameter indexPath: The index path of the row.
     
     - parameter orientation: The side of the cell requesting this information.
     
     - returns: An array of `SwipeAction` objects representing the actions for the row. Each action you provide is used to create a button that the user can tap.  Returning `nil` will prevent swiping for the supplied orientation.
     */
    func scrollView(_ scrollView: UIScrollView, editActionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> [SwipeAction]?
    
    /**
     Asks the delegate for the display options to be used while presenting the action buttons.
     
     - parameter scrollView: The table view or collection View object which owns the cell requesting this information.
     
     - parameter indexPath: The index path of the row.
     
     - parameter orientation: The side of the cell requesting this information.
     
     - returns: A `SwipeOptions` instance which configures the behavior of the action buttons.
     
     - note: If not implemented, a default `SwipeOptions` instance is used.
     */
    func scrollView(_ scrollView: UIScrollView, editActionsOptionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> SwipeOptions
    
    /**
     Tells the delegate that the table view is about to go into editing mode.

     - parameter scrollView: The table view or collection View object providing this information.
     
     - parameter indexPath: The index path of the row.
     
     - parameter orientation: The side of the cell.
    */
    func scrollView(_ scrollView: UIScrollView, willBeginEditingRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation)

    /**
     Tells the delegate that the table view has left editing mode.
     
     - parameter scrollView: The table view or collection View object providing this information.
     
     - parameter indexPath: The index path of the row.
     
     - parameter orientation: The side of the cell.
     */
    func scrollView(_ scrollView: UIScrollView, didEndEditingRowAt indexPath: IndexPath?, for orientation: SwipeActionsOrientation)
    
    /**
     Asks the delegate for visibile rectangle of the table view, which is used to ensure swipe actions are vertically centered within the visible portion of the cell.
     
     - parameter scrollView: The table view or collection View object providing this information.
     
     - returns: The visible rectangle of the table view.
     
     - note: The returned rectange should be in the table view's own coordinate system. Returning `nil` will result in no vertical offset to be be calculated.
     */
    func visibleRect(for scrollView: UIScrollView) -> CGRect?
}

/**
 Default implementation of `SwipeScrollViewCellDelegate` methods
 */
public extension SwipeScrollViewCellDelegate {
    func scrollView(_ scrollView: UIScrollView, editActionsOptionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> SwipeOptions {
        return SwipeOptions()
    }
    
    func scrollView(_ scrollView: UIScrollView, willBeginEditingRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) {}
    
    func scrollView(_ scrollView: UIScrollView, didEndEditingRowAt indexPath: IndexPath?, for orientation: SwipeActionsOrientation) {}
    
    func visibleRect(for scrollView: UIScrollView) -> CGRect? {
        return nil
    }
}
