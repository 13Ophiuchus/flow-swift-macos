#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${1:-FlowVaporApp}"
ROOT_DIR="/Users/nicreich/flow-swift-macos"

echo "Using project name: ${PROJECT_NAME}"
cd "$ROOT_DIR"

# 1. Create Vapor web template
if [ -d "$PROJECT_NAME" ]; then
  echo "Directory ${PROJECT_NAME} already exists, skipping vapor new."
else
  echo "Creating Vapor project..."
  vapor new "$PROJECT_NAME" --template=web --no-git
fi

cd "$PROJECT_NAME"

# 2. Update Package.swift to depend on local Flow package and Leaf
echo "Patching Package.swift..."

# Replace the whole file with a tailored one
cat > Package.swift << 'EOF'
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "App",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "App", targets: ["App"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.2.4"),
        // Local Flow package
        .package(path: "../")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Flow", package: "Flow"),
            ],
            resources: [
                .copy("Resources/Views")
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "XCTVapor", package: "vapor"),
            ]
        )
    ]
)
EOF

# 3. Create Resources/Views and Leaf templates
echo "Creating Leaf templates..."
mkdir -p Sources/App/Resources/Views

# base.leaf
cat > Sources/App/Resources/Views/base.leaf << 'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>#(title)</title>
  </head>
  <body>
    #import("body")
  </body>
</html>
EOF

# index.leaf
cat > Sources/App/Resources/Views/index.leaf << 'EOF'
#extend("base"):

#export("title"):Flow + Vapor#indexport

#export("body"):
<h1>Flow + Vapor</h1>
<p>#(description)</p>

<form method="get" action="/account">
  <label for="address">Flow address (hex):</label>
  <input type="text" id="address" name="address" />
  <button type="submit">Lookup</button>
</form>
#endexport
EOF

# account.leaf
cat > Sources/App/Resources/Views/account.leaf << 'EOF'
#extend("base"):

#export("title"):Account details#indexport

#export("body"):
<h1>Account</h1>

<p>Address: #(address)</p>

#if(error):
  <p style="color: red;">Error: #(error)</p>
#elseif(balance):
  <p>Balance: #(balance)</p>
#else:
  <p>No data.</p>
#endif
#endexport
EOF

# 4. Configure Vapor app to use Leaf and Flow + BatchProcessor
echo "Configuring main.swift and routes..."

# main.swift
cat > Sources/App/main.swift << 'EOF'
import Vapor
import Leaf
import Flow

@main
struct Main {
    static func main() throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let app = Application(env)
        defer { app.shutdown() }

        try configure(app)
        try routes(app)

        try app.run()
    }
}

func configure(_ app: Application) throws {
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.views.use(.leaf)
}
EOF

# routes.swift
cat > Sources/App/routes.swift << 'EOF'
import Vapor
import Flow

func routes(_ app: Application) throws {
    app.get { req async throws -> View in
        struct IndexContext: Encodable {
            let title: String
            let description: String
        }
        let ctx = IndexContext(title: "Flow + Vapor",
                               description: "Query Flow and render HTML with Leaf")
        return try await req.view.render("index", ctx)
    }

    app.get("account") { req async throws -> View in
        struct AccountContext: Encodable {
            let title: String
            let address: String
            let balance: String?
            let error: String?
        }

        let addressStr = try req.query.get(String.self, at: "address")

        do {
            let flowAddress = try Flow.Address(hex: addressStr)

            // Example using BatchProcessor for a single address
            let processor = BatchProcessor()
            let result = try await processor.processAccounts([flowAddress], maxConcurrent: 1)
            let data = result[flowAddress]

            let ctx = AccountContext(
                title: "Account details",
                address: addressStr,
                balance: data?["balance"],
                error: nil
            )
            return try await req.view.render("account", ctx)
        } catch {
            let ctx = AccountContext(
                title: "Account details",
                address: addressStr,
                balance: nil,
                error: error.localizedDescription
            )
            return try await req.view.render("account", ctx)
        }
    }
}
EOF

echo "Done. To run the app:"
echo "cd \"$ROOT_DIR/$PROJECT_NAME\""
echo "swift run"
