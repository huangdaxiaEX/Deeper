//
//  Query.swift
//  DeeperFunc
//
//  Created by Ilya Puchka on 26/10/2017.
//  Copyright © 2017 Ilya Puchka. All rights reserved.
//

import Foundation

infix operator .? : MultiplicationPrecedence

// TODO: why not to clear out query params after they are matched?
func queryParam<A>(_ key: String, _ apply: @escaping (String) -> A?, _ unapply: @escaping (A) -> String?) -> RoutePattern<A, Query> {
    return .init(
        parse: { route in
            guard let queryValue = route.query[key], let parsed = apply(queryValue) else { return nil }
            return (route, parsed)
    }, print: { a in
        guard let value = unapply(a) else { return RouteComponents(path: [], query: [:]) }
        return RouteComponents(path: [], query: [key: value])
    }, template: "\(key)=:\(typeKey(A.self))")
}

public func string(_ key: String) -> RoutePattern<String, Query> {
    return queryParam(key, { $0 }, { $0 })
}

public func int(_ key: String) -> RoutePattern<Int, Query> {
    return queryParam(key, Int.init, String.init)
}

public func double(_ key: String) -> RoutePattern<Double, Query> {
    return queryParam(key, Double.init, String.init)
}

public func bool(_ key: String) -> RoutePattern<Bool, Query> {
    return queryParam(key, { $0 == "1" ? true : $0 == "0" ? false : Bool($0.lowercased()) }, { $0 ? "true" : "false" })
}

extension RoutePattern where S == Query {

    static func or(_ lhs: RoutePattern, _ rhs: RoutePattern) -> RoutePattern {
        return .init(parse: parseAny(lhs, rhs), print: printAny(lhs, rhs), template: templateOr(lhs, rhs))
    }

    public static func .?(lhs: RoutePattern<Void, Path>, rhs: RoutePattern) -> RoutePattern {
        return .init(parse: parseRight(lhs, rhs), print: printRight(lhs, rhs), template: templateAnd(lhs, rhs))
    }
    
    public static func .?<B>(lhs: RoutePattern<B, Path>, rhs: RoutePattern) -> RoutePattern<(B, A), Query> {
        return .init(parse: parseBoth(lhs, rhs), print: printBoth(lhs, rhs), template: templateAnd(lhs, rhs))
    }

    public static func &<B>(lhs: RoutePattern, rhs: RoutePattern<B, Query>) -> RoutePattern<(A, B), Query> {
        return .init(parse: parseBoth(lhs, rhs), print: printBoth(lhs, rhs), template: templateAnd(lhs, rhs))
    }
    
    public static func |(lhs: RoutePattern, rhs: RoutePattern) -> RoutePattern {
        return .init(parse: parseAny(lhs, rhs), print: printAny(lhs, rhs), template: templateOr(lhs, rhs))
    }
    
    public static func |<B>(lhs: RoutePattern, rhs: RoutePattern<B, Query>) -> RoutePattern<Either<A, B>, Query> {
        return .init(parse: parseEither(lhs, rhs), print: printEither(lhs, rhs), template: templateOr(lhs, rhs))
    }
    
}
