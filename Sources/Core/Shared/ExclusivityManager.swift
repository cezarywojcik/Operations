//
//  ExclusivityManager.swift
//  Operations
//
//  Created by Daniel Thorpe on 27/06/2015.
//  Copyright (c) 2015 Daniel Thorpe. All rights reserved.
//

import Foundation

internal class ExclusivityManager {

    static let sharedInstance = ExclusivityManager()

    fileprivate let queue = Queue.initiated.serial("me.danthorpe.Operations.Exclusivity")
    fileprivate var operations: [String: [AdvancedOperation]] = [:]

    fileprivate init() {
        // A private initalizer prevents any other part of the app
        // from creating an instance.
    }

    func addOperation(_ operation: AdvancedOperation, category: String) -> Operation? {
        return dispatch_sync_legacy_with_result(queue: queue) { self._addOperation(operation, category: category) }
    }

    func removeOperation(_ operation: AdvancedOperation, category: String) {
        queue.async {
            self._removeOperation(operation, category: category)
        }
    }

    fileprivate func _addOperation(_ operation: AdvancedOperation, category: String) -> Operation? {
        operation.log.verbose(">>> \(category)")

        operation.addObserver(DidFinishObserver { [unowned self] op, _ in
            self.removeOperation(op, category: category)
        })

        var operationsWithThisCategory = operations[category] ?? []

        let previous = operationsWithThisCategory.last

        if let previous = previous {
            operation.addDependencyOnPreviousMutuallyExclusiveOperation(previous)
        }

        operationsWithThisCategory.append(operation)

        operations[category] = operationsWithThisCategory

        return previous
    }

    fileprivate func _removeOperation(_ operation: AdvancedOperation, category: String) {
        operation.log.verbose("<<< \(category)")

        if let operationsWithThisCategory = operations[category], let index = operationsWithThisCategory.index(of: operation) {
            var mutableOperationsWithThisCategory = operationsWithThisCategory
            mutableOperationsWithThisCategory.remove(at: index)
            operations[category] = mutableOperationsWithThisCategory
        }
    }
}

extension ExclusivityManager {

    /// This should only be used as part of the unit testing
    /// and in v2+ will not be publically accessible
    internal func __tearDownForUnitTesting() {
        dispatch_sync_legacy(queue: queue) {
            for (category, operations) in self.operations {
                for operation in operations {
                    operation.cancel()
                    self._removeOperation(operation, category: category)
                }
            }
        }
    }
}

open class ExclusivityManagerDebug {

    open static func debugData() -> OperationDebugData {
        let allCategoriesDebugData: [OperationDebugData] =
            ExclusivityManager.sharedInstance.operations.flatMap { (category, operationsArray) in
                guard !operationsArray.isEmpty else {
                    return nil
                }
                let categoryDebugData = operationsArray.map { $0.debugData() }
                return OperationDebugData(description: category, subOperations: categoryDebugData)
        }
        return OperationDebugData(description: "\(self)", subOperations: allCategoriesDebugData)
    }

}
