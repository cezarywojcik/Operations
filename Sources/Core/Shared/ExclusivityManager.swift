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

    private let queue = Queue.Initiated.serial("me.danthorpe.Operations.Exclusivity")
    private var operations: [String: [AdvancedOperation]] = [:]

    private init() {
        // A private initalizer prevents any other part of the app
        // from creating an instance.
    }

    func addOperation(operation: AdvancedOperation, category: String) -> NSOperation? {
        return dispatch_sync(queue) { self._addOperation(operation, category: category) }
    }

    func removeOperation(operation: AdvancedOperation, category: String) {
        dispatch_async(queue) {
            self._removeOperation(operation, category: category)
        }
    }

    private func _addOperation(operation: AdvancedOperation, category: String) -> NSOperation? {
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

    private func _removeOperation(operation: AdvancedOperation, category: String) {
        operation.log.verbose("<<< \(category)")

        if let operationsWithThisCategory = operations[category], index = operationsWithThisCategory.indexOf(operation) {
            var mutableOperationsWithThisCategory = operationsWithThisCategory
            mutableOperationsWithThisCategory.removeAtIndex(index)
            operations[category] = mutableOperationsWithThisCategory
        }
    }
}

extension ExclusivityManager {

    /// This should only be used as part of the unit testing
    /// and in v2+ will not be publically accessible
    internal func __tearDownForUnitTesting() {
#if swift(>=2.3)
        Dispatch.dispatch_sync(queue) {
            for (category, operations) in self.operations {
                for operation in operations {
                    operation.cancel()
                    self._removeOperation(operation, category: category)
                }
            }
        }
#else
        dispatch_sync(queue) {
            for (category, operations) in self.operations {
                for operation in operations {
                    operation.cancel()
                    self._removeOperation(operation, category: category)
                }
            }
        }
#endif
    }
}

public class ExclusivityManagerDebug {

    public static func debugData() -> OperationDebugData {
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
