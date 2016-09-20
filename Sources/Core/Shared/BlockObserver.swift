//
//  BlockObserver.swift
//  Operations
//
//  Created by Daniel Thorpe on 27/06/2015.
//  Copyright (c) 2015 Daniel Thorpe. All rights reserved.
//

import Foundation

public typealias DidAttachToOperationBlock = (_ operation: AdvancedOperation) -> Void

/**
 WillStartObserver is an observer which will execute a
 closure when the operation starts.
 */
public struct WillExecuteObserver: OperationWillExecuteObserver {
    public typealias BlockType = (_ operation: AdvancedOperation) -> Void

    fileprivate let block: BlockType

    /// - returns: a block which is called when the observer is attached to an operation
    public var didAttachToOperation: DidAttachToOperationBlock? = .none

    /**
     Initialize the observer with a block.

     - parameter didStart: the `DidStartBlock`
     - returns: an observer.
     */
    public init(willExecute: @escaping BlockType) {
        self.block = willExecute
    }

    /// Conforms to `OperationWillStartObserver`, executes the block
    public func willExecuteOperation(_ operation: AdvancedOperation) {
        block(operation)
    }

    /// Base OperationObserverType method
    public func didAttachToOperation(_ operation: AdvancedOperation) {
        didAttachToOperation?(operation)
    }
}

@available(*, unavailable, renamed: "WillExecuteObserver")
public typealias StartedObserver = WillExecuteObserver

/**
 WillCancelObserver is an observer which will execute a
 closure when the operation cancels.
 */
public struct WillCancelObserver: OperationWillCancelObserver {
    public typealias BlockType = (_ operation: AdvancedOperation, _ errors: [Error]) -> Void

    fileprivate let block: BlockType

    /// - returns: a block which is called when the observer is attached to an operation
    public var didAttachToOperation: DidAttachToOperationBlock? = .none

    /**
     Initialize the observer with a block.

     - parameter didStart: the `DidStartBlock`
     - returns: an observer.
     */
    public init(willCancel: @escaping BlockType) {
        self.block = willCancel
    }

    /// Conforms to `OperationWillCancelObserver`, executes the block
    public func willCancelOperation(_ operation: AdvancedOperation, errors: [Error]) {
        block(operation, errors)
    }

    /// Base OperationObserverType method
    public func didAttachToOperation(_ operation: AdvancedOperation) {
        didAttachToOperation?(operation)
    }
}


/**
 DidCancelObserver is an observer which will execute a
 closure when the operation cancels.
 */
public struct DidCancelObserver: OperationDidCancelObserver {
    public typealias BlockType = (_ operation: AdvancedOperation) -> Void

    fileprivate let block: BlockType

    /// - returns: a block which is called when the observer is attached to an operation
    public var didAttachToOperation: DidAttachToOperationBlock? = .none

    /**
     Initialize the observer with a block.

     - parameter didStart: the `DidStartBlock`
     - returns: an observer.
     */
    public init(didCancel: @escaping BlockType) {
        self.block = didCancel
    }

    /// Conforms to `OperationDidCancelObserver`, executes the block
    public func didCancelOperation(_ operation: AdvancedOperation) {
        block(operation)
    }

    /// Base OperationObserverType method
    public func didAttachToOperation(_ operation: AdvancedOperation) {
        didAttachToOperation?(operation)
    }
}

@available(*, unavailable, renamed: "DidCancelObserver")
public typealias CancelledObserver = DidCancelObserver


/**
 ProducedOperationObserver is an observer which will execute a
 closure when the operation produces another observer.
 */
public struct ProducedOperationObserver: OperationDidProduceOperationObserver {
    public typealias BlockType = (_ operation: AdvancedOperation, _ produced: Operation) -> Void

    fileprivate let block: BlockType

    /// - returns: a block which is called when the observer is attached to an operation
    public var didAttachToOperation: DidAttachToOperationBlock? = .none

    /**
     Initialize the observer with a block.

     - parameter didStart: the `DidStartBlock`
     - returns: an observer.
     */
    public init(didProduce: @escaping BlockType) {
        self.block = didProduce
    }

    /// Conforms to `OperationDidProduceOperationObserver`, executes the block
    public func operation(_ operation: AdvancedOperation, didProduceOperation newOperation: Operation) {
        block(operation, newOperation)
    }

    /// Base OperationObserverType method
    public func didAttachToOperation(_ operation: AdvancedOperation) {
        didAttachToOperation?(operation)
    }
}


/**
 WillFinishObserver is an observer which will execute a
 closure when the operation is about to finish.
 */
public struct WillFinishObserver: OperationWillFinishObserver {
    public typealias BlockType = (_ operation: AdvancedOperation, _ errors: [Error]) -> Void

    fileprivate let block: BlockType

    /// - returns: a block which is called when the observer is attached to an operation
    public var didAttachToOperation: DidAttachToOperationBlock? = .none

    /**
     Initialize the observer with a block.

     - parameter didStart: the `DidStartBlock`
     - returns: an observer.
     */
    public init(willFinish: @escaping BlockType) {
        self.block = willFinish
    }

    /// Conforms to `OperationWillFinishObserver`, executes the block
    public func willFinishOperation(_ operation: AdvancedOperation, errors: [Error]) {
        block(operation, errors)
    }

    /// Base OperationObserverType method
    public func didAttachToOperation(_ operation: AdvancedOperation) {
        didAttachToOperation?(operation)
    }
}


/**
 DidFinishObserver is an observer which will execute a
 closure when the operation did just finish.
 */
public struct DidFinishObserver: OperationDidFinishObserver {
    public typealias BlockType = (_ operation: AdvancedOperation, _ errors: [Error]) -> Void

    fileprivate let block: BlockType

    /// - returns: a block which is called when the observer is attached to an operation
    public var didAttachToOperation: DidAttachToOperationBlock? = .none

    /**
     Initialize the observer with a block.

     - parameter didStart: the `DidStartBlock`
     - returns: an observer.
     */
    public init(didFinish: @escaping BlockType) {
        self.block = didFinish
    }

    /// Conforms to `OperationDidFinishObserver`, executes the block
    public func didFinishOperation(_ operation: AdvancedOperation, errors: [Error]) {
        block(operation, errors)
    }

    /// Base OperationObserverType method
    public func didAttachToOperation(_ operation: AdvancedOperation) {
        didAttachToOperation?(operation)
    }
}

@available(*, unavailable, renamed: "DidFinishObserver")
public typealias FinishedObserver = DidFinishObserver

/**
 A `OperationObserver` which accepts three different blocks for start,
 produce and finish.
 */
public struct BlockObserver: OperationObserver {

    let willExecute: WillExecuteObserver?
    let willCancel: WillCancelObserver?
    let didCancel: DidCancelObserver?
    let didProduce: ProducedOperationObserver?
    let willFinish: WillFinishObserver?
    let didFinish: DidFinishObserver?

    /// - returns: a block which is called when the observer is attached to an operation
    public var didAttachToOperation: DidAttachToOperationBlock? = .none

    /**
     A `OperationObserver` which accepts three different blocks for start,
     produce and finish.

     The arguments all default to `.None` which means that the most
     typical use case for observing when the operation finishes. e.g.

     operation.addObserver(BlockObserver { _, errors in
     // The operation finished, maybe with errors,
     // which you should handle.
     })

     - parameter startHandler, a optional block of type Operation -> Void
     - parameter cancellationHandler, a optional block of type Operation -> Void
     - parameter produceHandler, a optional block of type (Operation, NSOperation) -> Void
     - parameter finishHandler, a optional block of type (Operation, [ErrorType]) -> Void
     */
    public init(willExecute: WillExecuteObserver.BlockType? = .none, willCancel: WillCancelObserver.BlockType? = .none, didCancel: DidCancelObserver.BlockType? = .none, didProduce: ProducedOperationObserver.BlockType? = .none, willFinish: WillFinishObserver.BlockType? = .none, didFinish: DidFinishObserver.BlockType? = .none) {
        self.willExecute = willExecute.map { WillExecuteObserver(willExecute: $0) }
        self.willCancel = willCancel.map { WillCancelObserver(willCancel: $0) }
        self.didCancel = didCancel.map { DidCancelObserver(didCancel: $0) }
        self.didProduce = didProduce.map { ProducedOperationObserver(didProduce: $0) }
        self.willFinish = willFinish.map { WillFinishObserver(willFinish: $0) }
        self.didFinish = didFinish.map { DidFinishObserver(didFinish: $0) }
    }

    /// Conforms to `OperationWillExecuteObserver`
    public func willExecuteOperation(_ operation: AdvancedOperation) {
        willExecute?.willExecuteOperation(operation)
    }

    /// Conforms to `OperationWillCancelObserver`
    public func willCancelOperation(_ operation: AdvancedOperation, errors: [Error]) {
        willCancel?.willCancelOperation(operation, errors: errors)
    }

    /// Conforms to `OperationDidCancelObserver`
    public func didCancelOperation(_ operation: AdvancedOperation) {
        didCancel?.didCancelOperation(operation)
    }

    /// Conforms to `OperationDidProduceOperationObserver`
    public func operation(_ operation: AdvancedOperation, didProduceOperation newOperation: Operation) {
        didProduce?.operation(operation, didProduceOperation: newOperation)
    }

    /// Conforms to `OperationWillFinishObserver`
    public func willFinishOperation(_ operation: AdvancedOperation, errors: [Error]) {
        willFinish?.willFinishOperation(operation, errors: errors)
    }

    /// Conforms to `OperationDidFinishObserver`
    public func didFinishOperation(_ operation: AdvancedOperation, errors: [Error]) {
        didFinish?.didFinishOperation(operation, errors: errors)
    }

    /// Base OperationObserverType method
    public func didAttachToOperation(_ operation: AdvancedOperation) {
        didAttachToOperation?(operation)
    }
}
