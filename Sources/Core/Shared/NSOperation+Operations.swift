//
//  NSOperation+Operations.swift
//  Operations
//
//  Created by Justin Newitter on 7/18/16.
//
//

import Foundation

extension NSOperation {

    /**
     Special case handling for fetching `OperationDebugData` on an `NSOperation`. Ideally this extension
     would just conform to the `OperationDebuggable` protocol and implement `debugData()`, but swift
     currently doesn't allow method overrides when extensions are involved. By making `NSOperation`
     implement `debugData` this would prevent all subclasses from implementing it (`Operation` and
     `GroupOperation`). To get around this we are adding a special method just for `NSOperation` and
     the debug generation code needs to have specific handling for it.
     */
    public func debugDataNSOperation() -> OperationDebugData {
        return OperationDebugData(
            description: "NSOperation: \(self)",
            properties: [
                "cancelled": String(cancelled),
                "ready": String(ready),
                "executing": String(executing),
                "finished": String(finished),
                "QOS": String(qualityOfService)
            ],
            conditions: [],
            dependencies: self.dependencies.map { ($0 as? OperationDebuggable)?.debugData() ?? $0.debugDataNSOperation()})
    }

}
