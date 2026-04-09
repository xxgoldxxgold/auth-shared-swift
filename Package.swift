// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AuthShared",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "AuthShared", targets: ["AuthShared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "AuthShared",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),
    ]
)
