//
//  StartCallConvertible.swift
//  Runner
//
//  Created by Zaid on 12/1/23.
//


protocol StartCallConvertible {

    var startCallHandle: String? { get }
    var video: Bool? { get }

}

extension StartCallConvertible {

    var video: Bool? {
        return nil
    }

}

