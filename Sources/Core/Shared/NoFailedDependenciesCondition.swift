//
//  NoFailedDependenciesCondition.swift
//  Operations
//
//  Created by Daniel Thorpe on 27/07/2015.
//  Copyright (c) 2015 Daniel Thorpe. All rights reserved.
//

import Foundation

/**
A condition that specificed that every dependency of the
operation must succeed. If any dependency fails/cancels,
the target operation will be fail.
*/
open class NoFailedDependenciesCondition: Condition {

    /// The `ErrorType` returned to indicate the condition failed.
    public enum ErrorType: Error, Equatable {

        /// When some dependencies were cancelled
        case cancelledDependencies

        /// When some dependencies failed with errors
        case failedDependencies
    }

    /// Initializer which takes no parameters.
    public override init() {
        super.init()
        name = "No Cancelled Condition"
        mutuallyExclusive = false
    }

    /**
    Evaluates the operation with respect to the finished status of its dependencies.

    The condition first checks if any dependencies were cancelled, in which case it
    fails with an `NoFailedDependenciesCondition.Error.CancelledDependencies`. Then
    it checks to see if any dependencies failed due to errors, in which case it
    fails with an `NoFailedDependenciesCondition.Error.FailedDependencies`.

    The cancelled or failed operations are no associated with the error.

    - parameter operation: the `Operation` which the condition is attached to.
    - parameter completion: the completion block which receives a `OperationConditionResult`.
     */
    open override func evaluate(_ operation: AdvancedOperation, completion: @escaping CompletionBlockType) {
        let dependencies = operation.dependencies

        let cancelled = dependencies.filter { $0.isCancelled }
        let failures = dependencies.filter {
            if let operation = $0 as? AdvancedOperation {
                return operation.failed
            }
            return false
        }

        if !cancelled.isEmpty {
            completion(.failed(ErrorType.cancelledDependencies))
        }
        else if !failures.isEmpty {
            completion(.failed(ErrorType.failedDependencies))
        }
        else {
            completion(.satisfied)
        }
    }
}

/// Equatable conformance for `NoFailedDependenciesCondition.Error`
public func == (lhs: NoFailedDependenciesCondition.ErrorType, rhs: NoFailedDependenciesCondition.ErrorType) -> Bool {
    switch (lhs, rhs) {
    case (.cancelledDependencies, .cancelledDependencies), (.failedDependencies, .failedDependencies):
        return true
    default:
        return false
    }
}
