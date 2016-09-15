//
//  Support.swift
//  Operations
//
//  Created by Daniel Thorpe on 25/06/2015.
//  Copyright (c) 2015 Daniel Thorpe. All rights reserved.
//

import Foundation

extension Dictionary {

    internal init<Sequence: Swift.Sequence>(sequence: Sequence, keyMapper: (Value) -> Key?) where Sequence.Iterator.Element == Value {
        self.init()
        for item in sequence {
            if let key = keyMapper(item) {
                self[key] = item
            }
        }
    }
}
