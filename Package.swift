// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TodoList",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "TodoList", targets: ["TodoList"])
    ],
    targets: [
        .executableTarget(
            name: "TodoList",
            path: "Sources/TodoList"
        ),
        .testTarget(
            name: "TodoListTests",
            dependencies: ["TodoList"],
            path: "Tests/TodoListTests"
        )
    ]
)
