//
//  NetworkObserver.swift
//  Operations
//
//  Created by Daniel Thorpe on 19/07/2015.
//  Copyright © 2015 Daniel Thorpe. All rights reserved.
//

import UIKit

protocol NetworkActivityIndicatorInterface {
    var isNetworkActivityIndicatorVisible: Bool { get set }
}

extension UIApplication: NetworkActivityIndicatorInterface { }

/**
An `OperationObserverType` which can be used to manage the network
activity indicator in iOS. Note that this is not an observer of
when the network is available. See `ReachableOperation`.
*/
open class NetworkObserver: OperationWillExecuteObserver, OperationDidFinishObserver {

    let networkActivityIndicator: NetworkActivityIndicatorInterface

    /// Initializer takes no parameters.
    public convenience init() {
        self.init(indicator: UIApplication.shared)
    }

    init(indicator: NetworkActivityIndicatorInterface) {
        networkActivityIndicator = indicator
    }

    /// Conforms to `OperationObserver`, will start the network activity indicator.
    open func willExecuteOperation(_ operation: AdvancedOperation) {
        Queue.main.queue.async {
            NetworkIndicatorController.sharedInstance.networkActivityIndicator = self.networkActivityIndicator
            NetworkIndicatorController.sharedInstance.networkActivityDidStart()
        }
    }

    /// Conforms to `OperationObserver`, will stop the network activity indicator.
    open func didFinishOperation(_ operation: AdvancedOperation, errors: [Error]) {
        Queue.main.queue.async {
            NetworkIndicatorController.sharedInstance.networkActivityIndicator = self.networkActivityIndicator
            NetworkIndicatorController.sharedInstance.networkActivityDidEnd()
        }
    }
}

private class NetworkIndicatorController {

    static let sharedInstance = NetworkIndicatorController()

    fileprivate var activityCount = 0
    fileprivate var visibilityTimer: Timer?

    var networkActivityIndicator: NetworkActivityIndicatorInterface = UIApplication.shared

    fileprivate init() {
        // Prevents use outside of the shared instance.
    }

    fileprivate func updateIndicatorVisibility() {
        if activityCount > 0 && networkActivityIndicator.isNetworkActivityIndicatorVisible == false {
            networkIndicatorShouldShow(true)
        }
        else if activityCount == 0 {
            visibilityTimer = Timer(interval: 1.0) {
                self.networkIndicatorShouldShow(false)
            }
        }
    }

    fileprivate func networkIndicatorShouldShow(_ shouldShow: Bool) {
        visibilityTimer?.cancel()
        visibilityTimer = .none
        networkActivityIndicator.isNetworkActivityIndicatorVisible = shouldShow
    }

    // Public API

    func networkActivityDidStart() {
        assert(Thread.isMainThread, "Altering network activity indicator state can only be done on the main thread.")
        activityCount += 1
        updateIndicatorVisibility()
    }

    func networkActivityDidEnd() {
        assert(Thread.isMainThread, "Altering network activity indicator state can only be done on the main thread.")
        activityCount -= 1
        updateIndicatorVisibility()
    }
}

private struct Timer {

    fileprivate var isCancelled = false

    init(interval: TimeInterval, handler: @escaping ()->()) {
        let after = DispatchTime.now() + interval
        Queue.main.queue.asyncAfter(deadline: after) { [isCancelled] in
            if isCancelled != true {
                handler()
            }
        }
    }

    mutating func cancel() {
        isCancelled = true
    }
}
