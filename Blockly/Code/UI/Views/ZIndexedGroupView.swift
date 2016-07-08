/*
 * Copyright 2016 Google Inc. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

/**
 Protocol that a `UIView` must conform to in order to be inserted into a `ZIndexedGroupView`.
 */
public protocol ZIndexedView {
  /// The z-index of the view. Views with higher z-index values will always appear above ones with
  /// lower values.
  var zIndex: UInt { get }
}

/**
 UIView which *only* holds views that conform to `ZIndexedView`, where views are ordered in the
 subview list by their `zIndex` property. This causes each view to be rendered and hit-tested inside
 `ZIndexedGroupView` based on their `zIndex`.

 - Note: All views should be added via `upsertView(:)`. Using any other insertion method
 on this class may have adverse effects. Adding any view other than one that conforms to
 `ZIndexedView` will result in an app crash.
 */
public final class ZIndexedGroupView: UIView {
  /// The highest z-index `UIView` that has been added to this group
  private var highestInsertedZIndex: UInt = 0

  /**
   Inserts or updates a `UIView` in this group, where it is sorted amongst other subviews based on
   its `zIndex`.

   - Parameter view: A `UIView` that conforms to `ZIndexedView`
   */
  public func upsertView<T where T: UIView, T:ZIndexedView>(view: T) {
    let zIndex = view.zIndex

    // More often than not, the target view's zIndex will be >= the zIndex of the highest
    // subview anyway. Quickly check to see if that's the case.
    if zIndex >= highestInsertedZIndex {
      upsertViewAtEnd(view)
      return
    }

    let isUpdateOperation = (view.superview == self)
    if isUpdateOperation {
      // If `view` is already in this group, temporarily move it to the end.
      // NOTE: `view` is purposely not removed from this view prior to running this method, as
      // it will cause any active gesture recognizers on the `view` to be cancelled. Therefore,
      // the `view` is simply skipped over if it is found in the binary search.
      upsertViewAtEnd(view)
    }

    // Binary search to find the correct position of where the view should be, based on its
    // z-index.

    // Calling self.subviews is very expensive -- internally, it does not appear to be an array
    // and is constructed dynamically when called. Only call it once and stuff it in a local var.
    let subviews = self.subviews

    // Initialize clamps
    var min = 0
    var max = isUpdateOperation ?
      // Don't include the last index since that's where the given `view` is now positioned
      (subviews.count - 1) :
      subviews.count

    while (min < max) {
      let currentMid = (min + max) / 2
      let currentZIndex = (subviews[currentMid] as! ZIndexedView).zIndex

      if (currentZIndex < zIndex) {
        min = currentMid + 1
      } else if (currentZIndex > zIndex) {
        max = currentMid
      } else {
        min = currentMid
        break
      }
    }

    // Upsert `view` at the new index
    upsertView(view, atIndex: min)
  }

  private func upsertViewAtEnd<T where T: UIView, T:ZIndexedView>(view: T) {
    upsertView(view, atIndex: -1)
  }

  /**
   Upserts a view into the group.

   - Parameter view: The `UIView` to upsert
   - Parameter index: The index to upsert `view` at. If the value is < 0, `view` is
   automatically upserted to the end of `self.subviews`.
   */
  private func upsertView<T where T: UIView, T:ZIndexedView>(view: T, atIndex index: Int) {
    if index >= 0 {
      // Calling insertSubview(...) on a view that is already a subview just updates its
      // position in `self.subviews`.
      // Note: Inserting (or re-inserting) a subview at an `index` greater than the number of
      // subviews does not cause an error, it simply puts it at the end.
      insertSubview(view, atIndex: index)
    } else {
      // Calling addSubview(_) always adds the view to the end of `self.subviews` (regardless of
      // whether the view was already a subview) and brings it to appear on top of all other
      // subviews.
      addSubview(view)
    }

    if view.zIndex >= highestInsertedZIndex {
      highestInsertedZIndex = view.zIndex
    }
  }
}