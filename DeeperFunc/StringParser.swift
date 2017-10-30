//
//  StringParser.swift
//  DeeperFunc
//
//  Created by Ilya Puchka on 31/10/2017.
//  Copyright © 2017 Ilya Puchka. All rights reserved.
//

import Foundation

typealias StringParser<S: PatternState> = ([String]) -> (rest: [String], match: RoutePattern<Any, S>)?

struct StringRouteParser<S: PatternState> {
    let parse: StringParser<S>
}

func parseComponents<S>(_ components: [String], parsers: StringParser<S>...) -> (rest: [String], match: [RoutePattern<Any, S>])? {
    var components = components
    var pathPatterns: [RoutePattern<Any, S>] = []
    
    componentsLoop: while !components.isEmpty {
        for parser in parsers {
            if let result = parser(components) {
                components = result.rest
                pathPatterns.append(result.match)
                continue componentsLoop
            }
        }
        return nil
    }
    
    return (components, pathPatterns)
}

func parsePathParam<A>(pattern: RoutePattern<A, Path>, _ apply: @escaping (String) -> A?) -> StringParser<Path> {
    return {
        guard pathParamTemplate(A.self) == $0.first else { return nil }

        let typeErased: RoutePattern<Any, Path> = pattern.typeErased(apply)
        return (Array($0.dropFirst()), typeErased)
    }
}

let intPath: StringParser<Path> = parsePathParam(pattern: int, Int.init)
let doublePath: StringParser<Path> = parsePathParam(pattern: double, Double.init)
let stringPath: StringParser<Path> = parsePathParam(pattern: string, { $0 })
let litPath: StringParser<Path> = { components in
    guard var pathComponent = components.first else { return nil }
    let typeErased: RoutePattern<Any, Path> = lit(pathComponent).typeErased()
    return (Array(components.dropFirst()), typeErased)
}

let anyEndPath: StringParser<Path> = { components in
    guard components.count == 1, components[0] == "*" else { return nil }
    return ([], any.typeErased())
}

let anyPath: StringParser<Path> = { components in
    guard components.count > 1, components[0] == "*", components[1] != "*" else { return nil }
    guard let result = parseComponents([components[1]], parsers: intPath, doublePath, stringPath, litPath) else { return nil }
    guard !result.match.isEmpty else { return nil }
    
    return (result.rest, any(result.match[0]).typeErased())
}

func parsePathComponents(_ components: [String]) -> [RoutePattern<Any, Path>]? {
    return parseComponents(components, parsers: anyEndPath, anyPath, intPath, doublePath, stringPath, litPath)?.match
}

func parseQueryParam<A>(pattern: @escaping (String) -> RoutePattern<A, Query>, _ apply: @escaping (String) -> A?) -> StringParser<Query> {
    return {
        guard var queryComponent = $0.first else { return nil }
        guard queryComponent.trimSuffix(queryParamTemplate(A.self, key: "")) else { return nil }
        
        let typeErased: RoutePattern<Any, Query> = pattern(queryComponent).typeErased(apply)
        return (Array($0.dropFirst()), typeErased)
    }
}

let intQuery: StringParser<Query> = parseQueryParam(pattern: int, Int.init)
let doubleQuery: StringParser<Query> = parseQueryParam(pattern: double, Double.init)
let boolQuery: StringParser<Query> = parseQueryParam(pattern: bool, Bool.fromString)
let stringQuery: StringParser<Query> = parseQueryParam(pattern: string, { $0 })

func parseQueryComponents(_ components: [String]) -> [RoutePattern<Any, Query>]? {
    return parseComponents(components, parsers: intQuery, doubleQuery, boolQuery, stringQuery)?.match
}

func .?(lhs: RoutePattern<Any, Path>, rhs: [RoutePattern<Any, Query>]) -> RoutePattern<Any, Path> {
    if !rhs.isEmpty {
        var rhsPattern: RoutePattern<Any, Query> = (lhs .? rhs[0]).typeErased({ $0 as? (Any, Any) })
        rhsPattern = rhs.suffix(from: 1).reduce(rhsPattern, and)
        return rhsPattern.typeErased()
    } else {
        return lhs
    }
}

extension String {
    
    var pathPattern: RoutePattern<Any, Path>? {
        let path = index(of: "?").map(prefix(upTo:)).map(String.init) ?? self
        let pathComponents = path.components(separatedBy: "/", excludingDelimiterBetween: ("(", ")"))
        
        guard let pathPatterns = parsePathComponents(pathComponents) else { return nil }
        
        let pathPattern = pathPatterns.suffix(from: 1).reduce(pathPatterns[0], and)
        return pathPattern
    }
    
    var queryPatterns: [RoutePattern<Any, Query>]? {
        guard let queryStart = index(of: "?") else { return [] }
        
        let query = String(suffix(from: queryStart).dropFirst())
        let queryComponents = query.components(separatedBy: "&", excludingDelimiterBetween: ("(", ")"))
        return parseQueryComponents(queryComponents)
    }
    
    public var routePattern: RoutePattern<Any, Path>? {
        guard let pathPattern = pathPattern, let queryPatterns = queryPatterns else { return nil }
        return pathPattern .? queryPatterns
    }
    
}

extension RoutePattern where A == Void {
    func typeErased<S>() -> RoutePattern<Any, S> {
        return map({ _ in () as Any }, { _ in () })
    }
}

extension RoutePattern where A == Any {
    func typeErased<S2>() -> RoutePattern<Any, S2> {
        return map({ $0 }, { $0 })
    }
}

extension RoutePattern {
    func typeErased<S2>(_ apply: @escaping (String) -> A?) -> RoutePattern<Any, S2> {
        return map({ $0 }, { apply(String(describing: $0)) })
    }
    
    func typeErased<S2>(_ apply: @escaping (Any) -> A?) -> RoutePattern<Any, S2> {
        return map({ $0 }, { apply($0) })
    }
}

func and(_ lhs: RoutePattern<Any, Path>, _ rhs: RoutePattern<Any, Path>) -> RoutePattern<Any, Path> {
    return .init(parse: { url in
        guard let lhsResult = lhs.parse(url) else { return nil }
        guard let rhsResult = rhs.parse(lhsResult.0) else { return nil }
        return (rhsResult.0, flatten(lhsResult.match, rhsResult.match ))
    }, print: { value in
        if let (lhsValue, rhsValue) = value as? (Any, Any), let lhs = lhs.print(lhsValue), let rhs = rhs.print(rhsValue) {
            return RouteComponents(lhs.path + rhs.path, lhs.query.merging(rhs.query, uniquingKeysWith: { $1 }))
        } else if let lhs = lhs.print(value), let rhs = rhs.print(value)  {
            return RouteComponents(lhs.path + rhs.path, lhs.query.merging(rhs.query, uniquingKeysWith: { $1 }))
        } else {
            return nil
        }
    }, template: templateAnd(lhs, rhs))
}

func and(_ lhs: RoutePattern<Any, Query>, _ rhs: RoutePattern<Any, Query>) -> RoutePattern<Any, Query> {
    return .init(parse: { url in
        guard let lhsResult = lhs.parse(url) else { return nil }
        guard let rhsResult = rhs.parse(lhsResult.0) else { return nil }
        return (rhsResult.0, flatten(lhsResult.match, rhsResult.match ))
    }, print: { value in
        if let (lhsValue, rhsValue) = value as? (Any, Any), let lhs = lhs.print(lhsValue), let rhs = rhs.print(rhsValue) {
            return RouteComponents(lhs.path + rhs.path, lhs.query.merging(rhs.query, uniquingKeysWith: { $1 }))
        } else {
            return nil
        }
    }, template: templateAnd(lhs, rhs))
}