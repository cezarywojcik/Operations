//
//  GroupOperation.swift
//  Operations
//
//  Created by Daniel Thorpe on 18/07/2015.
//  Copyright © 2015 Daniel Thorpe. All rights reserved.
//

import Foundation

// swiftlint:disable file_length

/**
An `Operation` subclass which enables the grouping
of other operations. Use `GroupOperation`s to associate
related operations together, thereby creating higher
levels of abstractions.

Additionally, `GroupOperation`s are useful as a way
of creating Operations which may repeat themselves before
subsequent operations can run. For example, authentication
operations.
*/
open class GroupOperation: AdvancedOperation, OperationQueueDelegate {

    typealias ErrorsByOperation = [Operation: [Error]]
    internal struct Errors {
        var fatal = Array<Error>()
        var attemptedRecovery: ErrorsByOperation = [:]

        var previousAttempts: [Error] {
            return Array(FlattenCollection(attemptedRecovery.values))
        }

        var all: [Error] {
            get {
                var tmp: [Error] = fatal
                tmp.append(contentsOf: previousAttempts)
                return tmp
            }
        }
    }

    fileprivate let finishingOperation = Foundation.BlockOperation { }
    fileprivate var protectedErrors = Protector(Errors())
    fileprivate var canFinishOperation: GroupOperation.CanFinishOperation!
    fileprivate var isGroupFinishing = false
    fileprivate let groupFinishLock = NSRecursiveLock()
    fileprivate var isAddingOperationsGroup = DispatchGroup()

    /// - returns: the AdvancedOperationQueue the group runs operations on.
    open let queue = AdvancedOperationQueue()

    /// - returns: the operations which have been added to the queue
    open fileprivate(set) var operations: [Operation] {
        get {
            return _operations.read { $0 }
        }
        set {
            _operations.write { (ward: inout [Operation]) in
                ward = newValue
            }
        }
    }
    fileprivate var _operations: Protector<[Operation]>

    open override var userIntent: AdvancedOperation.UserIntent {
        didSet {
            let (nsops, ops) = operations.splitNSOperationsAndOperations
            nsops.forEach { $0.setQualityOfServiceFromUserIntent(userIntent) }
            ops.forEach { $0.userIntent = userIntent }
        }
    }

    /**
    Designated initializer.

    - parameter operations: an array of `NSOperation`s.
    */
    public init(operations ops: [Operation]) {
        _operations = Protector<[Operation]>(ops)
        // GroupOperation handles calling finish() on cancellation once all of its children have cancelled and finished
        // and its finishingOperation has finished.
        super.init(disableAutomaticFinishing: true) // Override default Operation finishing behavior
        canFinishOperation = GroupOperation.CanFinishOperation(parentGroupOperation: self)
        name = "Group Operation"
        queue.isSuspended = true
        queue.delegate = self
        userIntent = operations.userIntent
        addObserver(DidCancelObserver { [unowned self] operation in
            if operation === self {
                let errors = operation.errors
                if errors.isEmpty {
                    self.operations.forEach { $0.cancel() }
                }
                else {
                    let (nsops, ops) = self.operations.splitNSOperationsAndOperations
                    nsops.forEach { $0.cancel() }
                    ops.forEach { $0.cancelWithError(OperationError.parentOperationCancelledWithErrors(errors)) }
                }
            }
        })
    }

    /// Convenience initializer for direct usage without subclassing.
    public convenience init(operations: Operation...) {
        self.init(operations: operations)
    }

    /**
     Executes the group by adding the operations to the queue. Then
     starting the queue, and adding the finishing operation.
    */
    open override func execute() {
        _addOperations(operations.filter { !self.queue.operations.contains($0) }, addToOperationsArray: false)
        _addCanFinishOperation(canFinishOperation)
        queue.addOperation(finishingOperation)
        queue.isSuspended = false
    }

    /**
     Add an `NSOperation` to the group's queue.

     - parameter operation: an `NSOperation` instance.
    */
    open func addOperation(_ operation: Operation) {
        addOperations(operation)
    }

    /**
     Add multiple operations at once.

     - parameter operations: an array of `NSOperation` instances.
     */
    open func addOperations(_ operations: Operation...) {
        addOperations(operations)
    }

    /**
     Add multiple operations at once.

     - parameter operations: an array of `NSOperation` instances.
     */
    open func addOperations(_ additional: [Operation]) {
        _addOperations(additional, addToOperationsArray: true)
    }

    fileprivate func _addOperations(_ additional: [Operation], addToOperationsArray: Bool = true) {

        if additional.count > 0 {

            let shouldAddOperations = groupFinishLock.withCriticalScope { () -> Bool in
                guard !isGroupFinishing else { return false }
                isAddingOperationsGroup.enter()
                return true
            }

            guard shouldAddOperations else {
                if !finishingOperation.isFinished {
                    assertionFailure("Cannot add new operations to a group after the group has started to finish.")
                }
                else {
                    assertionFailure("Cannot add new operations to a group after the group has completed.")
                }
                return
            }

            var handledCancelled = false
            if isCancelled {
                additional.forEachOperation { $0.cancel() }
                handledCancelled = true
            }
            let logSeverity = log.severity
            additional.forEachOperation { $0.log.severity = logSeverity }

            queue.addOperations(additional)

            if addToOperationsArray {
                _operations.appendContentsOf(additional)
            }

            if !handledCancelled && isCancelled {
                // It is possible that the cancellation happened before adding the
                // additional operations to the operations array.
                // Thus, ensure that all additional operations are cancelled.
                additional.forEachOperation { if !$0.isCancelled { $0.cancel() } }
            }

            groupFinishLock.withCriticalScope {
                isAddingOperationsGroup.leave()
            }
        }
    }

    /**
     This method is called when a child operation in the group will finish with errors.

     Often an operation will finish with errors become some of its pre-requisites were not
     met. Errors of this nature should be recoverable. This can be done by re-trying the
     original operation, but with another operation which fulfil the pre-requisites as a
     dependency.

     If the errors were recovered from, return true from this method, else return false.

     Errors which are not handled will result in the Group finishing with errors.

     - parameter errors: an [ErrorType], the errors of the child operation
     - parameter operation: the child operation which is finishing
     - returns: a Boolean, return true if the errors were handled, else return false.
     */
    open func willAttemptRecoveryFromErrors(_ errors: [Error], inOperation operation: Operation) -> Bool {
        return false
    }

    /**
     This method is only called when a child operation finishes without any errors.

     - parameter operation: the child operation which will finish without errors
    */
    open func willFinishOperation(_ operation: Operation) {
        // no-op
    }

    @available(*, unavailable, message: "Refactor your GroupOperation subclass as this method is no longer used.\n Override willFinishOperation(_: NSOperation) to manage scheduling of child operations. Override willAttemptRecoveryFromErrors(_: [ErrorType], inOperation: NSOperation) to do error handling. See code documentation for more details.")
    open func willFinishOperation(_ operation: Operation, withErrors errors: [Error]) { }

    @available(*, unavailable, renamed: "willFinishOperation")
    open func operationDidFinish(_ operation: Operation, withErrors errors: [Error]) { }

    internal func child(_ child: Operation, didEncounterFatalErrors errors: [Error]) {
        addFatalErrors(errors)
    }

    internal func child(_ child: Operation, didAttemptRecoveryFromErrors errors: [Error]) {
        protectedErrors.write { (tmp: inout Errors) in
            tmp.attemptedRecovery[child] = errors
        }
    }

    // MARK: - OperationQueueDelegate

    /**
     The group operation acts as its own queue's delegate. When an operation is added to the queue,
     assuming that the group operation is not yet finishing or finished, then we add the operation
     as a dependency to an internal "barrier" operation that separates executing from finishing state.

     The purpose of this is to keep the internal operation as a final child operation that executes
     when there are no more operations in the group operation, safely handling the transition of
     group operation state.
     */
    open func operationQueue(_ queue: AdvancedOperationQueue, willAddOperation operation: Operation) {
        guard queue === self.queue else { return }

        assert(!finishingOperation.isExecuting, "Cannot add new operations to a group after the group has started to finish.")
        assert(!finishingOperation.isFinished, "Cannot add new operations to a group after the group has completed.")

        if operation !== finishingOperation {
            let shouldContinue = groupFinishLock.withCriticalScope { () -> Bool in
                guard !isGroupFinishing else {
                    assertionFailure("Cannot add new operations to a group after the group has started to finish.")
                    return false
                }
                isAddingOperationsGroup.enter()
                return true
            }

            guard shouldContinue else { return }

            willAddChildOperationObservers.forEach { $0.groupOperation(self, willAddChildOperation: operation) }

            canFinishOperation.addDependency(operation)

            groupFinishLock.withCriticalScope {
                isAddingOperationsGroup.leave()
            }
        }
    }

    /**
     The group operation acts as it's own queue's delegate. When an operation finishes, if the
     operation is the finishing operation, we finish the group operation here. Else, the group is
     notified (using `operationDidFinish` that a child operation has finished.
     */
    open func operationQueue(_ queue: AdvancedOperationQueue, willFinishOperation operation: Operation, withErrors errors: [Error]) {
        guard queue === self.queue else { return }

        if !errors.isEmpty {
            if willAttemptRecoveryFromErrors(errors, inOperation: operation) {
                child(operation, didAttemptRecoveryFromErrors: errors)
            }
            else {
                child(operation, didEncounterFatalErrors: errors)
            }
        }
        else if operation !== finishingOperation {
            willFinishOperation(operation)
        }
    }

    open func operationQueue(_ queue: AdvancedOperationQueue, didFinishOperation operation: Operation, withErrors errors: [Error]) {
        guard queue === self.queue else { return }

        if operation === finishingOperation {
            finish(fatalErrors)
            queue.isSuspended = true
        }
    }

    open func operationQueue(_ queue: AdvancedOperationQueue, willProduceOperation operation: Operation) {
        guard queue === self.queue else { return }

        // Ensure that produced operations are added to GroupOperation's
        // internal operations array (and cancelled if appropriate)

        let shouldContinue = groupFinishLock.withCriticalScope { () -> Bool in
            assert(!finishingOperation.isFinished, "Cannot produce new operations within a group after the group has completed.")
            guard !isGroupFinishing else {
                assertionFailure("Cannot produce new operations within a group after the group has started to finish.")
                return false
            }
            isAddingOperationsGroup.enter()
            return true
        }

        guard shouldContinue else { return }

        _operations.append(operation)
        if isCancelled && !operation.isCancelled {
            operation.cancel()
        }

        groupFinishLock.withCriticalScope {
            isAddingOperationsGroup.leave()
        }
    }

    /**
     This method is used for debugging the current state of a `GroupOperation`.

     - returns: An `OperationDebugData` object containing debug data for the current `GroupOperation`.
     */
    override open func debugData() -> OperationDebugData {
        let operationData = super.debugData()
        let queueData = queue.debugData()
        return OperationDebugData(
            description: "GroupOperation: \(self)",
            properties: operationData.properties,
            conditions: operationData.conditions,
            dependencies:  operationData.dependencies,
            subOperations: queueData.subOperations)
    }
}

public extension GroupOperation {

    internal var internalErrors: Errors {
        return protectedErrors.read { $0 }
    }

    /// - returns: the errors which could not be recovered from
    var fatalErrors: [Error] {
        return internalErrors.fatal
    }

    /**
     Appends a fatal error.
     - parameter error: an ErrorType
    */
    final func addFatalError(_ error: Error) {
        addFatalErrors([error])
    }

    /**
     Appends an array of fatal errors.
     - parameter errors: an [ErrorType]
     */
    final func addFatalErrors(_ errors: [Error]) {
        protectedErrors.write { (tmp: inout Errors) in
            tmp.fatal.append(contentsOf: errors)
        }
    }

    internal func didRecoverFromOperationErrors(_ operation: Operation) {
        if let _ = internalErrors.attemptedRecovery[operation] {
            log.verbose("successfully recovered from errors in \(operation)")
            protectedErrors.write { (tmp: inout Errors) in
                tmp.attemptedRecovery.removeValue(forKey: operation)
            }
        }
    }

    internal func didNotRecoverFromOperationErrors(_ operation: Operation) {
        log.verbose("failed to recover from errors in \(operation)")
        protectedErrors.write { (tmp: inout Errors) in
            if let errors = tmp.attemptedRecovery.removeValue(forKey: operation) {
                tmp.fatal.append(contentsOf: errors)
            }
        }
    }
}

public extension GroupOperation {

    @available(*, unavailable, renamed: "fatalErrors")
    var aggregateErrors: [Error] {
        return fatalErrors
    }

    @available(*, unavailable, renamed: "addFatalError")
    final func aggregateError(_ error: Error) {
        addFatalError(error)
    }
}

public protocol GroupOperationWillAddChildObserver: OperationObserverType {

    func groupOperation(_ group: GroupOperation, willAddChildOperation child: Operation)
}

extension GroupOperation {

    internal var willAddChildOperationObservers: [GroupOperationWillAddChildObserver] {
        return observers.flatMap { $0 as? GroupOperationWillAddChildObserver }
    }
}

/**
 WillAddChildObserver is an observer which will execute a
 closure when the group operation it is attaches to adds a
 child operation to its queue.
 */
public struct WillAddChildObserver: GroupOperationWillAddChildObserver {
    public typealias BlockType = (_ group: GroupOperation, _ child: Operation) -> Void

    fileprivate let block: BlockType

    /// - returns: a block which is called when the observer is attached to an operation
    public var didAttachToOperation: DidAttachToOperationBlock? = .none

    /**
     Initialize the observer with a block.

     - parameter willAddChild: the `WillAddChildObserver.BlockType`
     - returns: an observer.
     */
    public init(willAddChild: @escaping BlockType) {
        self.block = willAddChild
    }

    /// Conforms to GroupOperationWillAddChildObserver
    public func groupOperation(_ group: GroupOperation, willAddChildOperation child: Operation) {
        block(group, child)
    }

    /// Base OperationObserverType method
    public func didAttachToOperation(_ operation: AdvancedOperation) {
        didAttachToOperation?(operation)
    }
}

private extension GroupOperation {
    /**
     The group operation handles thread-safe addition of operations by utilizing two final operations:
     - a CanFinishOperation which manages handling GroupOperation internal state and has every child
       operation as a dependency
     - a finishingOperation, which has the CanFinishOperation as a dependency

     The purpose of this is to handle the possibility that GroupOperation.addOperation() or
     GroupOperation.queue.addOperation() are called right after all current child operations have
     completed (i.e. after the CanFinishOperation has been set to ready), but *prior* to being able
     to process that the GroupOperation is finishing (i.e. prior to the CanFinishOperation executing and
     acquiring the GroupOperation.groupFinishLock to set state).
     */
    class CanFinishOperation: Operation {
        fileprivate weak var parent: GroupOperation?
        fileprivate var _finished = false
        fileprivate var _executing = false

        init(parentGroupOperation: GroupOperation) {
            self.parent = parentGroupOperation
            super.init()
        }
        override func start() {

            // Override NSOperation.start() because this operation may have to
            // finish asynchronously (if it has to register to be notified when
            // operations are no longer being added concurrently).
            //
            // Since we override start(), it is important to send NSOperation
            // isExecuting / isFinished KVO notifications.
            //
            // (Otherwise, the operation may not be released, there may be
            // problems with dependencies, with the queue's handling of
            // maxConcurrentOperationCount, etc.)

            isExecuting = true

            main()
        }
        override func main() {
            execute()
        }
        func execute() {
            if let parent = parent {

                // All operations that were added as a side-effect of anything up to
                // WillFinishObservers of prior operations should have been executed.
                //
                // Handle an edge case caused by concurrent calls to GroupOperation.addOperations()

                let isWaiting = parent.groupFinishLock.withCriticalScope { () -> Bool in

                    // Is anything currently adding operations?
                    guard parent.isAddingOperationsGroup.wait(timeout: DispatchTime.now()) == .success else {
                        // Operations are actively being added to the group
                        // Wait for this to complete before proceeding.
                        //
                        // Register to dispatch a new call to execute() in the future, after the
                        // wait completes (i.e. after concurrent calls to GroupOperation.addOperations()
                        // have completed), and return from this call to execute() without finishing
                        // the operation.
                        parent.isAddingOperationsGroup.notify(queue: Queue(qos: qualityOfService).queue, execute: execute)
                        return true
                    }

                    // Check whether new operations were added prior to the lock
                    // by checking for child operations that are not finished.

                    let activeOperations = parent.operations.filter({ !$0.isFinished })
                    if !activeOperations.isEmpty {

                        // Child operations were added after this CanFinishOperation became
                        // ready, but before it executed or before the lock could be acquired.
                        //
                        // The GroupOperation should wait for these child operations to finish
                        // before finishing. Add the oustanding child operations as
                        // dependencies to a new CanFinishOperation, and add that as the
                        // GroupOperation's new CanFinishOperation.

                        let newCanFinishOp = GroupOperation.CanFinishOperation(parentGroupOperation: parent)

                        activeOperations.forEach { op in
                            newCanFinishOp.addDependency(op)
                        }

                        parent.canFinishOperation = newCanFinishOp

                        parent._addCanFinishOperation(newCanFinishOp)
                    }
                    else {
                        // There are no additional operations to handle.
                        // Ensure that no new operations can be added.
                        parent.isGroupFinishing = true
                    }
                    return false
                }

                guard !isWaiting else { return }
            }

            isExecuting = false
            isFinished = true
        }
        override fileprivate(set) var isExecuting: Bool {
            get {
                return _executing
            }
            set {
                willChangeValue(forKey: "isExecuting")
                _executing = newValue
                didChangeValue(forKey: "isExecuting")
            }
        }
        override fileprivate(set) var isFinished: Bool {
            get {
                return _finished
            }
            set {
                willChangeValue(forKey: "isFinished")
                _finished = newValue
                didChangeValue(forKey: "isFinished")
            }
        }
    }

    func _addCanFinishOperation(_ canFinishOperation: GroupOperation.CanFinishOperation) {
        finishingOperation.addDependency(canFinishOperation)
        queue._addCanFinishOperation(canFinishOperation)
    }
}

private extension AdvancedOperationQueue {
    func _addCanFinishOperation(_ canFinishOperation: GroupOperation.CanFinishOperation) {
        // Do not add observers (not needed - CanFinishOperation is an implementation detail of GroupOperation)
        // Do not add conditions (CanFinishOperation has none)
        // Call NSOperationQueue.addOperation() directly
        super.addOperation(canFinishOperation)
    }
}
