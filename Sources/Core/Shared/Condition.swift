//
//  ConditionOperation.swift
//  Operations
//
//  Created by Daniel Thorpe on 15/04/2016.
//
//

import Foundation

public protocol ConditionType {

    var mutuallyExclusive: Bool { get set }

    func evaluate(operation: AdvancedOperation, completion: ConditionResult -> Void)
}

internal extension ConditionType {

    internal var category: String {
        return "\(self.dynamicType)"
    }
}

/// General Errors used by conditions
public enum ConditionError: ErrorType, Equatable {

    /// A FalseCondition may use this as the error
    case FalseCondition

    /**
     If the block returns false, the operation to
     which it is attached will fail with this error.
     */
    case BlockConditionFailed
}

public func == (lhs: ConditionError, rhs: ConditionError) -> Bool {
    switch (lhs, rhs) {
    case (.FalseCondition, .FalseCondition), (.BlockConditionFailed, .BlockConditionFailed):
        return true
    default:
        return false
    }
}


/**
 Condition Operation

 Conditions are a core feature of this framework. Multiple
 instances can be attached to an `Operation` subclass, whereby they
 are evaluated to determine whether or not the target operation is
 executed.

 ConditionOperation is also an Operation subclass, which means that it
 also benefits from all the features of Operation, namely dependencies,
 observers, and yes, conditions. This means that your conditions could
 have conditions. This allows for expressing incredibly rich control logic.

 Additionally, conditions are evaluated asynchronously, and indicate
 failure by passing an ConditionResult enum back.

 */
public class Condition: AdvancedOperation, ConditionType, ResultOperationType {

    public typealias CompletionBlockType = ConditionResult -> Void

    public var mutuallyExclusive: Bool = false

    internal weak var operation: AdvancedOperation? = .None

    public var result: ConditionResult! = nil

    public final override func execute() {
        guard let operation = operation else {
            assertionFailure("ConditionOperation executed before operation set.")
            finish()
            return
        }
        evaluate(operation, completion: finish)
    }

    /**
     Subclasses must override this method, but should not call super.
     - parameter operation: the Operation instance the condition was attached to
     - parameter completion: a completion block which receives a ConditionResult argument.
    */
    public func evaluate(operation: AdvancedOperation, completion: CompletionBlockType) {
        assertionFailure("ConditionOperation must be subclassed, and \(#function) overridden.")
        completion(.Failed(OperationError.ConditionFailed))
    }

    internal func finish(conditionResult: ConditionResult) {
        self.result = conditionResult
        finish(conditionResult.error)
    }
}


public class TrueCondition: Condition {

    public init(name: String = "True Condition", mutuallyExclusive: Bool = false) {
        super.init()
        self.name = name
        self.mutuallyExclusive = mutuallyExclusive
    }

    public override func evaluate(operation: AdvancedOperation, completion: CompletionBlockType) {
        completion(.Satisfied)
    }
}

public class FalseCondition: Condition {

    public init(name: String = "False Condition", mutuallyExclusive: Bool = false) {
        super.init()
        self.name = name
        self.mutuallyExclusive = mutuallyExclusive
    }

    public override func evaluate(operation: AdvancedOperation, completion: CompletionBlockType) {
        completion(.Failed(ConditionError.FalseCondition))
    }
}


/**
 Class which can be used to compose a Condition, it is designed to be subclassed.

 This can be useful to automatically manage the dependency and automatic
 injection of the composed condition result for evaluation inside your custom subclass.

 - see: NegatedCondition
 - see: SilentCondition
 */
public class ComposedCondition<C: Condition>: Condition, AutomaticInjectionOperationType {

    /**
     The composed condition.

     - parameter condition: a the composed `Condition`
     */
    public let condition: C

    override var directDependencies: Set<NSOperation> {
        return super.directDependencies.union(condition.directDependencies)
    }

    /// Conformance to `AutomaticInjectionOperationType`
    public var requirement: ConditionResult! = nil

    override var operation: AdvancedOperation? {
        didSet {
            condition.operation = operation
        }
    }

    /**
     Initializer which receives a conditon which is to be negated.

     - parameter [unnamed]: a nested `Condition` type.
     */
    public init(_ condition: C) {
        self.condition = condition
        super.init()
        mutuallyExclusive = condition.mutuallyExclusive
        name = condition.name
        injectResultFromDependency(condition) { operation, dependency, _ in
            operation.requirement = dependency.result
        }
    }

    /// Override of public function
    public override func evaluate(operation: AdvancedOperation, completion: CompletionBlockType) {
        guard let result = requirement else {
            completion(.Failed(AutomaticInjectionError.RequirementNotSatisfied))
            return
        }
        completion(result)
    }

    override func removeDirectDependency(directDependency: NSOperation) {
        condition.removeDirectDependency(directDependency)
        super.removeDirectDependency(directDependency)
    }
}

internal class WrappedOperationCondition: Condition {

    let condition: OperationCondition

    var category: String {
        return "\(condition.dynamicType)"
    }

    init(_ condition: OperationCondition) {
        self.condition = condition
        super.init()
        mutuallyExclusive = condition.isMutuallyExclusive
        name = condition.name
    }

    override func evaluate(operation: AdvancedOperation, completion: CompletionBlockType) {
        condition.evaluateForOperation(operation, completion: completion)
    }
}

extension Array where Element: NSOperation {

    internal var conditions: [Condition] {
        return flatMap { $0 as? Condition }
    }
}
