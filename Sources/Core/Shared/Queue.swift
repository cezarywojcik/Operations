//
//  Queue.swift
//  Operations
//
//  Created by Daniel Thorpe on 23/06/2016.
//
//

import Foundation

// MARK: - Queues

/**
 A nice Swift wrapper around `dispatch_queue_create`. The cases
 correspond to GCD's quality of service classes. To get the
 main queue use like this:

 dispatch_async(Queue.Main.queue) {
 print("I'm on the main queue!")
 }
 */
public enum Queue {

    internal final class Scheduler {

        private lazy var __once: () = {
            self.queue.setSpecific(key: self.key, value: self.context)
        }()

        fileprivate var once: Int = 0
        fileprivate var key = DispatchSpecificKey<UInt8>()
        fileprivate var context: UInt8 = 0
        fileprivate let queue: DispatchQueue

        init(queue: DispatchQueue) {
            self.queue = queue
            _ = self.__once
        }

        var isScheduleQueue: Bool {
            return DispatchQueue.getSpecific(key: self.key) == self.context
        }
    }

    /// returns: a Bool to indicate if the current queue is the main queue
    public static var isMainQueue: Bool {
        return mainQueueScheduler.isScheduleQueue
    }

    /// The main queue
    case main

    /// The default QOS
    case `default`

    /// Use for user initiated tasks which do not impact the UI. Such as data processing.
    case initiated

    /// Use for user initiated tasks which do impact the UI - e.g. a rendering pipeline.
    case interactive

    /// Use for non-user initiated task.
    case utility

    /// Backgound QOS is a severly limited class, should not be used for anything when the app is active.
    case background

    // swiftlint:disable variable_name
    fileprivate var qos_class: DispatchQoS.QoSClass {
        switch self {
        case .main: return DispatchQoS.QoSClass(rawValue: qos_class_main()) ?? .unspecified
        case .default: return DispatchQoS.QoSClass.default
        case .initiated: return DispatchQoS.QoSClass.userInitiated
        case .interactive: return DispatchQoS.QoSClass.userInteractive
        case .utility: return DispatchQoS.QoSClass.utility
        case .background: return DispatchQoS.QoSClass.background
        }
    }
    // swiftlint:enable variable_name

    /**
     Access the appropriate global `dispatch_queue_t`. For `.Main` this
     is the main queue, for other cases, it is the global queue for the
     appropriate `qos_class_t`.

     - parameter queue: the corresponding global dispatch_queue_t
     */
    public var queue: DispatchQueue {
        switch self {
        case .main: return DispatchQueue.main
        default: return DispatchQueue.global(qos: qos_class)
        }
    }

    /**
     Creates a named serial queue with the correct QOS class.

     Use like this:

     let queue = Queue.Utility.serial("me.danthorpe.Operation.eg")
     dispatch_async(queue) {
     print("I'm on a utility serial queue.")
     }
     */
    public func serial(_ named: String) -> DispatchQueue {
        return DispatchQueue(
            label: named,
            qos: DispatchQoS.init(qosClass: .default, relativePriority: Int(QOS_MIN_RELATIVE_PRIORITY)))
    }

    /**
     Creates a named concurrent queue with the correct QOS class.

     Use like this:

     let queue = Queue.Initiated.concurrent("me.danthorpe.Operation.eg")
     dispatch_barrier_async(queue) {
     print("I'm on a initiated concurrent queue.")
     }
     */
    public func concurrent(_ named: String) -> DispatchQueue {
        return DispatchQueue(
            label: named,
            qos: DispatchQoS.init(qosClass: .default, relativePriority: Int(QOS_MIN_RELATIVE_PRIORITY)),
            attributes: [.concurrent])
    }

    /**
     Initialize a Queue with a given NSQualityOfService.

     - parameter qos: a NSQualityOfService value
     - returns: a Queue with an equivalent quality of service
     */
    public init(qos: QualityOfService) {
        switch qos {
        case .background:
            self = .background
        case .default:
            self = .default
        case .userInitiated:
            self = .initiated
        case .userInteractive:
            self = .interactive
        case .utility:
            self = .utility
        }
    }

    /**
     Initialize a Queue with a given GCD quality of service class.

     - parameter qos: a qos_class_t value
     - returns: a Queue with an equivalent quality of service
     */
    public init(qos: DispatchQoS.QoSClass) {
        switch qos {
        case DispatchQoS.QoSClass(rawValue: qos_class_main()) ?? .unspecified:
            self = .main
        case DispatchQoS.QoSClass.background:
            self = .background
        case DispatchQoS.QoSClass.userInitiated:
            self = .initiated
        case DispatchQoS.QoSClass.userInteractive:
            self = .interactive
        case DispatchQoS.QoSClass.utility:
            self = .utility
        default:
            self = .default
        }
    }
}

internal let mainQueueScheduler = Queue.Scheduler(queue: Queue.main.queue)
