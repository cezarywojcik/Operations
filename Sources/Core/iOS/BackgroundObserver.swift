//
//  BackgroundObserver.swift
//  Operations
//
//  Created by Daniel Thorpe on 19/07/2015.
//  Copyright © 2015 Daniel Thorpe. All rights reserved.
//

import UIKit

public protocol BackgroundTaskApplicationInterface {
    var applicationState: UIApplication.State { get }
    func beginBackgroundTask(withName taskName: String?, expirationHandler handler: (() -> Void)?) -> UIBackgroundTaskIdentifier
    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier)
}

extension UIApplication: BackgroundTaskApplicationInterface { }

/**
An observer which will automatically start & stop a background task if the
application enters the background.

Attach a `BackgroundObserver` to an operation which must be completed even
if the app goes in the background.
*/
open class BackgroundObserver: NSObject {

    static let backgroundTaskName = "Background Operation Observer"

    fileprivate var identifier: UIBackgroundTaskIdentifier? = .none
    fileprivate let application: BackgroundTaskApplicationInterface

    fileprivate var isInBackground: Bool {
        return application.applicationState == .background
    }

    /// Initialize a `BackgroundObserver`, takes no parameters.
    public override convenience init() {
        self.init(app: UIApplication.shared)
    }

    init(app: BackgroundTaskApplicationInterface) {
        application = app

        super.init()

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(BackgroundObserver.didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: .none)
        nc.addObserver(self, selector: #selector(BackgroundObserver.didBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: .none)

        if isInBackground {
            startBackgroundTask()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func didEnterBackground(_ notification: Notification) {
        if isInBackground {
            startBackgroundTask()
        }
    }

    @objc func didBecomeActive(_ notification: Notification) {
        if !isInBackground {
            endBackgroundTask()
        }
    }

    fileprivate func startBackgroundTask() {
        if identifier == nil {
            identifier = application.beginBackgroundTask(withName: type(of: self).backgroundTaskName) {
                self.endBackgroundTask()
            }
        }
    }

    fileprivate func endBackgroundTask() {
        if let id = identifier {
            application.endBackgroundTask(id)
            identifier = .none
        }
    }
}

extension BackgroundObserver: OperationDidFinishObserver {

    /// Conforms to `OperationDidFinishObserver`, will end any background task that has been started.
    public func didFinishOperation(_ operation: AdvancedOperation, errors: [Error]) {
        endBackgroundTask()
    }
}
