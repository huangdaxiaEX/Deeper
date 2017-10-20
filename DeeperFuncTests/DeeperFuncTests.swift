//
//  DeeperFuncTests.swift
//  DeeperFuncTests
//
//  Created by Ilya Puchka on 26/10/2017.
//  Copyright © 2017 Ilya Puchka. All rights reserved.
//

import XCTest
import DeeperFunc

extension Either where A: Equatable, B: Equatable {

    static func ==(_ lhs: Either<A, B>, _ rhs: Either<A, B>) -> Bool {
        switch (lhs, rhs) {
        case let (.left(lhs), .left(rhs)): return lhs == rhs
        case let (.right(lhs), .right(rhs)): return lhs == rhs
        default: return false
        }
    }

}

class DeeperFuncTests: XCTestCase {
    
    enum Intent: Equatable {
        case empty
        case pathAndQueryParams(Int, String, Int, String)
        case singleParam(Int)
        case twoParams(Int, String)
        case anyMiddle
        case anyEnd
        case anyStart
        case anyMiddleParam(Int)
        case anyMiddleParams(Int, Int)
        case anyEndParam(Int)
        case anyStartParam(Int)
        case orPattern
        case eitherIntOrInt(Either<Int, Int>)
        case eitherIntOrString(Either<Int, String>)
        case eitherIntOrVoid(Either<Int, Void>)
        case optionalParam(Int?)
        case optionalSecondParam(Int, String?)
        
        static func ==(lhs: Intent, rhs: Intent) -> Bool {
            switch (lhs, rhs) {
            case (.empty, .empty): return true
            case let (.pathAndQueryParams(lhs), .pathAndQueryParams(rhs)): return lhs == rhs
            case let (.singleParam(lhs), .singleParam(rhs)): return lhs == rhs
            case let (.twoParams(lhs), .twoParams(rhs)): return lhs == rhs
            case (.anyMiddle, .anyMiddle): return true
            case (.anyEnd, .anyEnd): return true
            case (.anyStart, .anyStart): return true
            case let (.anyMiddleParam(lhs), .anyMiddleParam(rhs)): return lhs == rhs
            case let (.anyMiddleParams(lhs), .anyMiddleParams(rhs)): return lhs == rhs
            case let (.anyEndParam(lhs), .anyEndParam(rhs)): return lhs == rhs
            case let (.anyStartParam(lhs), .anyStartParam(rhs)): return lhs == rhs
            case (.orPattern, .orPattern): return true
            case let (.eitherIntOrInt(lhs), .eitherIntOrInt(rhs)): return lhs == rhs
            case let (.eitherIntOrString(lhs), .eitherIntOrString(rhs)): return lhs == rhs
            case let (.eitherIntOrVoid(lhs), .eitherIntOrVoid(rhs)):
                switch (lhs, rhs) {
                case let (.left(lhs), .left(rhs)): return lhs == rhs
                case (.right, .right): return true
                default: return false
                }
            case let (.optionalParam(lhs), .optionalParam(rhs)): return lhs == rhs
            case let (.optionalSecondParam(lhs1, lhs2), .optionalSecondParam(rhs1, rhs2)):
                return lhs1 == rhs1 && lhs2 == rhs2
            default: return false
            }
        }
    }
    
    var router: Router<Intent>!
    
    override func setUp() {
        router = Router<Intent>()
    }
    
    func AssertMatch(_ intent: Intent, _ url: String, file: StaticString = #file, line: UInt = #line) {
        let request = URLRequest(url: URL(string: url)!)
        let matched = router.match(request)
        XCTAssertNotNil(matched, file: file, line: line)
        XCTAssertEqual(matched, intent, file: file, line: line)
    }
    
    func AssertNotMatch(_ url: String, file: StaticString = #file, line: UInt = #line) {
        let request = URLRequest(url: URL(string: url)!)
        let matched = router.match(request)
        XCTAssertNil(matched, file: file, line: line)
    }

    func testSimpleRoute() {
        router.add(Intent.empty, "recipes" /> "info")
        
        AssertMatch(Intent.empty, "http://recipes/info")
        AssertNotMatch("http://recipes/data")
        AssertNotMatch("http://recipes")
        AssertNotMatch("http://recipes/info/123")
    }
    
    func testLongPattern() {
        router.add(Intent.empty, "recipes" /> "info" /> "a" /> "b" /> "c" /> "d" /> "e" /> "f")
        
        AssertMatch(Intent.empty, "http://recipes/info/a/b/c/d/e/f")
    }
    
    func testRouteWithPathParamAndQuery() {
        router.add(Intent.pathAndQueryParams, "recipes" /> int </> string .? int("recipeId") & string("t"))
        
        AssertMatch(Intent.pathAndQueryParams(123, "abc", 456, "A"), "http://recipes/123/abc?recipeId=456&t=A")
        AssertMatch(Intent.pathAndQueryParams(123, "abc", 456, "A"), "http://recipes/123/abc?t=A&recipeId=456")
        AssertNotMatch("http://recipes/abc/abc?recipeId=456&t=A")
        AssertNotMatch("http://recipes/abc?recipeId=456&t=A")
        AssertNotMatch("http://recipes/123/abc?recipeId=abc&t=A")
        AssertNotMatch("http://recipes/123/abc?t=A")
        AssertNotMatch("http://recipes/123/abc?recipeId=abc")
    }
    
    func testPathWithParams() {
        router.add(Intent.singleParam, "subscription" /> int)
        
        AssertMatch(Intent.singleParam(123), "http://subscription/123")
        AssertNotMatch("http://subscription/abc")
        AssertNotMatch("http://subscription/true")
        AssertNotMatch("http://subscription/abc/123")
        
        router.add(Intent.twoParams, "subscription" /> int </ "menu" </> string)
        AssertMatch(Intent.twoParams(123, "abc"), "http://subscription/123/menu/abc")
        AssertNotMatch("http://subscription/abc/menu/123")
    }
    
    func testAnyPatternInMiddleRoute() {
        router.add(Intent.anyMiddle, "recipes" /> "id" /> any /> "data" /> "abc")
        
        AssertMatch(Intent.anyMiddle, "http://recipes/id/123/foo/data/abc")
        AssertNotMatch("http://recipes/id/data/abc")

        router = Router()
        router.add(Intent.anyMiddleParam, "recipes" /> "id" /> any /> int </ "data" </ "abc")
        
        AssertMatch(Intent.anyMiddleParam(123), "http://recipes/id/foo/123/data/abc")
        AssertNotMatch("http://recipes/id/foo/123/456/data/abc")
        AssertNotMatch("http://recipes/id/123/data/abc")

        router = Router()
        router.add(Intent.anyMiddleParam, "recipes" /> "id" /> any /> "data" /> int </ "abc")
        
        AssertMatch(Intent.anyMiddleParam(456), "http://recipes/id/123/data/456/abc")
        AssertNotMatch("http://recipes/id/foo/data/abc")

        router = Router()
        router.add(Intent.anyMiddleParam, "recipes" /> "id" /> int </ any </ "data" </ "abc")
        
        AssertMatch(Intent.anyMiddleParam(123), "http://recipes/id/123/abc/foo/data/abc")
        AssertNotMatch("http://recipes/id/foo/data/abc")

        router = Router()
        router.add(Intent.anyMiddleParam, "recipes" /> int </ "id" </ any </ "data" </ "abc")
        
        AssertMatch(Intent.anyMiddleParam(123), "http://recipes/123/id/foo/data/abc")
        AssertNotMatch("http://recipes/id/abc/foo/data/abc")
        
        router = Router()
        router.add(Intent.anyMiddleParams, "recipes" /> "id" /> int </ any </ "data" </> int </ "abc")
        
        AssertMatch(Intent.anyMiddleParams(123, 456), "http://recipes/id/123/foo/data/456/abc")
        
        router = Router()
        router.add(Intent.anyMiddleParams, "recipes" /> "id" /> int </ any </ "data" </ any </> int </ "abc")
        AssertMatch(Intent.anyMiddleParams(123, 456), "http://recipes/id/123/foo/data/bar/456/abc")

        router = Router()
        router.add(Intent.anyMiddleParams, "recipes" /> int </ "id" </ any </> int </ "data" </ "abc")

        AssertMatch(Intent.anyMiddleParams(123, 456), "http://recipes/123/id/foo/456/data/abc")
        
        router = Router()
        router.add(Intent.anyMiddleParams, "recipes" /> "id" /> int </ any </> int </ "data" </ "abc")
        
        AssertMatch(Intent.anyMiddleParams(123, 456), "http://recipes/id/123/foo/456/data/abc")
    }

    func testAnyPatternAtStart() {
        router.add(Intent.anyStart, any /> "data" /> "abc")
        
        AssertMatch(Intent.anyStart, "http://foo/123/data/abc")
        AssertMatch(Intent.anyStart, "http://data/data/abc")
        AssertNotMatch("http://123/data/data/abc")

        router = Router()
        router.add(Intent.anyStartParam, any /> int </ "data" </ "abc")
        AssertMatch(Intent.anyStartParam(123), "http://foo/123/data/abc")

        router = Router()
        router.add(Intent.anyStartParam, any /> "data" /> int </ "abc")
        AssertMatch(Intent.anyStartParam(123), "http://foo/data/123/abc")
    }

    func testAnyPatternAtEndRoute() {
        router.add(Intent.anyEnd, "data" /> any)

        AssertMatch(Intent.anyEnd, "http://data/abc/123/456")
        AssertNotMatch("http://data")

        router = Router()
        router.add(Intent.anyEnd, "data" /> "abc" /> any)
        
        AssertMatch(Intent.anyEnd, "http://data/abc/123/456")
        AssertMatch(Intent.anyEnd, "http://data/abc/data/abc")
        AssertNotMatch("http://data/abc")

        router = Router()
        router.add(Intent.anyEndParam, "data" /> "abc" /> int </ any)
        AssertMatch(Intent.anyEndParam(123), "http://data/abc/123/456/abc")

        router = Router()
        router.add(Intent.anyEndParam, "data" /> int </ "abc" </ any)
        AssertMatch(Intent.anyEndParam(123), "http://data/123/abc/456/abc")
        
        router = Router()
        router.add(Intent.anyEndParam, "data" /> "abc" /> any .? int("id"))
        AssertMatch(Intent.anyEndParam(1), "http://data/abc/123/foo?id=1")
    }
    
    func testConditionInPath() {
        router.add(Intent.orPattern, "recipes" /> ("data" | "info") )

        AssertMatch(Intent.orPattern, "http://recipes/data")
        AssertMatch(Intent.orPattern, "http://recipes/info")
        AssertNotMatch("http://recipes/foo")
        
        router.add(Intent.eitherIntOrString, "recipes" /> ( int </ "info" | "data" /> string ) )
        
        AssertMatch(Intent.eitherIntOrString(.right("abc")), "http://recipes/data/abc")
        AssertMatch(Intent.eitherIntOrString(.left(123)), "http://recipes/123/info")
    }
    
    func testConditionInQuery() {
        router.add(Intent.eitherIntOrString, "recipes" .? ( int("info") | string("data") ) )
        
        AssertMatch(Intent.eitherIntOrString(.right("abc")), "http://recipes?data=abc")
        AssertMatch(Intent.eitherIntOrString(.left(123)), "http://recipes?info=123")
        
        router.add(Intent.eitherIntOrString, "recipes" .? ( "info" .? int("recipeId") | "data" .? string("id") ) )
        
        AssertMatch(Intent.eitherIntOrString(.right("abc")), "http://recipes/data?id=abc")
        AssertMatch(Intent.eitherIntOrString(.left(123)), "http://recipes/info?recipeId=123")
    }
    
    func testMaybePath() {
        router.add(Intent.empty, "recipes" /? "data" /> "info")
        
        AssertMatch(Intent.empty, "http://recipes/data/info")
        AssertMatch(Intent.empty, "http://recipes/info")
        
        AssertNotMatch("http://recipes/foo/info")
        AssertNotMatch("http://recipes/data/abc/info")
        
        router = Router()
        router.add(Intent.optionalParam, "recipes" /? int </ "info")

        AssertMatch(Intent.optionalParam(123), "http://recipes/123/info")
        AssertMatch(Intent.optionalParam(nil), "http://recipes/info")
        
        AssertNotMatch("http://recipes/foo/info")
        AssertNotMatch("http://recipes/123/abc/info")
    }
    
    func testMaybeQuery() {
        router.add(Intent.optionalParam, "recipes" .?? int("recipeId"))
        AssertMatch(Intent.optionalParam(123), "http://recipes?recipeId=123")
        AssertMatch(Intent.optionalParam(nil), "http://recipes")

        router = Router()
        router.add(Intent.optionalSecondParam, "recipes" .? int("recipeId") &? string("locale"))
        AssertMatch(Intent.optionalSecondParam(123, "en"), "http://recipes?recipeId=123&locale=en")
        AssertMatch(Intent.optionalSecondParam(123, nil), "http://recipes?recipeId=123")
    }
    
    func testTemplates() {
        let route = "recipes" /> (("info" | "archive") | string) </ "data"
        XCTAssertEqual(route.template, "recipes/((info|archive)|:string)/data")

        let paramRoute = "recipes" /> int /? "data"  </> string
        XCTAssertEqual(paramRoute.template, "recipes/:int/(data)/:string")

        let queryRoute = "recipes" /> int </ "data" </> string .? int("recipeId") & string("s") & bool("b")
        XCTAssertEqual(queryRoute.template, "recipes/:int/data/:string?recipeId=:int&s=:string&b=:bool")

        let complexRoute = "recipes" .? int("recipeId") & string("s") & (bool("b") | int("i"))
        XCTAssertEqual(complexRoute.template, "recipes?recipeId=:int&s=:string&(b=:bool|i=:int)")
        
        let anyRoute = any /> "recipes" /> any /> int </ "data" </> string </ any </ "info" </ any
        XCTAssertEqual(anyRoute.template, "*/recipes/*/:int/data/:string/*/info/*")
    }
}
