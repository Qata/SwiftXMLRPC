# SwiftXMLRPC

SwiftXMLRPC is a lightweight parser for [XMLRPC](http://xmlrpc.com/spec.md).

Under the hood, this project uses [SwiftParsec](https://github.com/davedufresne/SwiftParsec) to parse XML.

All types support serialization and parsing.

# Usage
## Parsing
    // success(SwiftXMLRPC.XMLRPC.Response.param(SwiftXMLRPC.XMLRPC.Parameter.double(1.0)))
    print(
        XMLRPC.Response.deserialize(
            from: """
            <?xml version="1.0" encoding="UTF-8"?><methodResponse><params><param><value><double>1.0</double></value></param></params></methodResponse>
            """,
            sourceName: "https://examplewebsite.com/XMLRPC"
        )
    )
## Serialization
    let xml = XMLRPC.Call(
        method: "example.method",
        param: .struct(
            [ "first": .string("item"),
              "second": .array([.double(1e9)]),
              "third": .date(Date())
            ]
        )
    ).serialize()
    
# Tests
Tests are writen with [SwiftCheck](https://github.com/typelift/SwiftCheck) and utilise roundtripping to catch bugs.
