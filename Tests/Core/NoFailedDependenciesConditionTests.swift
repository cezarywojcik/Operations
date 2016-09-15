//
//  NoFailedDependenciesConditionTests.swift
//  Operations
//
//  Created by Daniel Thorpe on 20/07/2015.
//  Copyright © 2015 Daniel Thorpe. All rights reserved.
//

import XCTest
@testable import Operations

class NoFailedDependenciesConditionTests: OperationTests {

    func createCancellingOperation(_ shouldCancel: Bool, expectation: XCTestExpectation) -> TestOperation {

        let operation = TestOperation()
        operation.name = shouldCancel ? "Cancelled Dependency" : "Successful Dependency"

        if !shouldCancel {
            addCompletionBlockToTestOperation(operation, withExpectation: expectation)
        }
        else {
            operation.addObserver(WillExecuteObserver { op in
                op.cancel()
                expectation.fulfill()
            })
        }
        return operation
    }

    func test__operation_with_no_dependencies_still_succeeds() {
        let operation = TestOperation()
        operation.addCondition(NoFailedDependenciesCondition())

        addCompletionBlockToTestOperation(operation, withExpectation: expectationWithDescription("Test: \(#function)"))
        runOperation(operation)

        waitForExpectations(timeout: 3, handler: nil)
        XCTAssertTrue(operation.finished)
    }

    func test__operation_with_sucessful_dependency_succeeds() {

        let operation = TestOperation()
        addCompletionBlockToTestOperation(operation, withExpectation: expectationWithDescription("Test: \(#function)"))
        let dependency = createCancellingOperation(false, expectation: expectation(description: "Dependency for Test: \(#function)"))
        operation.addDependency(dependency)
        operation.addCondition(NoFailedDependenciesCondition())

        runOperations(operation, dependency)
        waitForExpectations(timeout: 3, handler: nil)

        XCTAssertTrue(operation.finished)
    }

    func test__operation_with_single_cancelled_dependency_doesnt_execute() {

        let operation = TestOperation()
        let dependency = createCancellingOperation(true, expectation: expectation(description: "Dependency for Test: \(#function)"))
        operation.addDependency(dependency)
        operation.addCondition(NoFailedDependenciesCondition())

        runOperations(operation, dependency)
        waitForExpectations(timeout: 3, handler: nil)

        XCTAssertFalse(operation.didExecute)
    }

    func test__operation_with_mixture_fails() {
        let expectation = self.expectation(description: "Test: \(#function)")
        let operation = TestOperation()
        let dependency1 = createCancellingOperation(true, expectation: self.expectation(description: "Dependency 1 for Test: \(#function)"))
        operation.addDependency(dependency1)
        let dependency2 = createCancellingOperation(false, expectation: self.expectation(description: "Dependency 2 for Test: \(#function)"))
        operation.addDependency(dependency2)
        operation.addCondition(NoFailedDependenciesCondition())

        var receivedErrors = [Error]()
        operation.addObserver(BlockObserver { (_ , errors) in
            receivedErrors = errors
            expectation.fulfill()
        })

        runOperations(operation, dependency1, dependency2)
        waitForExpectations(timeout: 3, handler: nil)

        XCTAssertFalse(operation.didExecute)
        XCTAssertEqual(receivedErrors.count, 1)
    }

    func test__operation_with_errored_dependency_fails() {
        let expectation = self.expectation(description: "Test: \(#function)")
        let operation = TestOperation()
        let dependency = TestOperation(delay: 0, error: TestOperation.Error.simulatedError)
        operation.addDependency(dependency)
        operation.addCondition(NoFailedDependenciesCondition())

        var receivedErrors = [Error]()
        operation.addObserver(BlockObserver { (_ , errors) in
            receivedErrors = errors
            expectation.fulfill()
        })

        runOperations(operation, dependency)
        waitForExpectations(timeout: 3, handler: nil)

        XCTAssertFalse(operation.didExecute)
        XCTAssertEqual(receivedErrors.count, 1)
    }

    func test__operation_with_group_dependency_with_errored_child_fails() {
        LogManager.severity = .Verbose
        let expectation = self.expectation(description: "Test: \(#function)")

        let operation = TestOperation()
        operation.name = "Target Operation"

        let child = TestOperation(delay: 0, error: TestOperation.Error.simulatedError)
        child.name = "Child Operation"

        let dependency = GroupOperation(operations: [child])
        dependency.name = "Dependency"

        operation.addDependency(dependency)
        operation.addCondition(NoFailedDependenciesCondition())

        var receivedErrors = [Error]()
        operation.addObserver(BlockObserver { (_ , errors) in
            receivedErrors = errors
            expectation.fulfill()
        })

        runOperations(operation, dependency)
        waitForExpectations(timeout: 3, handler: nil)

        XCTAssertFalse(operation.didExecute)
        XCTAssertEqual(receivedErrors.count, 1)
        LogManager.severity = .Warning
    }
}

class NoFailedDependenciesConditionErrorTests: XCTestCase {

    var errorA: NoFailedDependenciesCondition.Error!
    var errorB: NoFailedDependenciesCondition.Error!

    func test__both_cancelled_equal() {
        errorA = .CancelledDependencies
        errorB = .CancelledDependencies
        XCTAssertEqual(errorA, errorB)
    }

    func test__both_failed_equal() {
        errorA = .FailedDependencies
        errorB = .FailedDependencies
        XCTAssertEqual(errorA, errorB)
    }

    func test__cancelled_and_failed_not_equal() {
        errorA = .CancelledDependencies
        errorB = .FailedDependencies
        XCTAssertNotEqual(errorA, errorB)
    }

    func test__failed_and_cancelled_not_equal() {
        errorA = .FailedDependencies
        errorB = .CancelledDependencies
        XCTAssertNotEqual(errorA, errorB)
    }
}
