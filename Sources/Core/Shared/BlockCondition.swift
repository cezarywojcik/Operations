//
//  BlockCondition.swift
//  Operations
//
//  Created by Daniel Thorpe on 22/07/2015.
//  Copyright (c) 2015 Daniel Thorpe. All rights reserved.
//

import Foundation

/**
A Condition which will be satisfied if the block returns true. The
 block may throw an error, or return false, both of which are
 intepretated as a condition failure.
*/
open class BlockCondition: Condition {

    /// The block type which returns a Bool.
    public typealias ConditionBlockType = () throws -> Bool

    public typealias Error = ConditionError

    let block: ConditionBlockType

    /**
    Creates a `BlockCondition` with the supplied block.

    Example like this..

        operation.addCondition(BlockCondition { true })

    Alternatively

        func checkFlag() -> Bool {
            return toDoSomethingOrNot
        }

        operation.addCondition(BlockCondition(block: checkFlag))

    - parameter block: a `ConditionBlockType`.
    */
    public init(name: String = "Block Condition", mutuallyExclusive: Bool = false, block: @escaping ConditionBlockType) {
        self.block = block
        super.init()
        self.mutuallyExclusive = mutuallyExclusive
        self.name = name
    }

    open override func evaluate(_ operation: AdvancedOperation, completion: @escaping CompletionBlockType) {
        do {
            let result = try block()
            completion(result ? .satisfied : .failed(Error.blockConditionFailed))
        }
        catch {
            completion(.failed(error))
        }
    }
}
