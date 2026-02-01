# gRPC Client Setup

This directory contains the gRPC client implementation for communicating with the Rushday backend.

**Note:** Uses grpc-swift v1.x which supports **iOS 12+** (v2.x requires iOS 18+).

## Setup Instructions

### 1. Add Swift Package Dependencies

In Xcode:
1. Go to **File > Add Package Dependencies**
2. Add the following packages:

**grpc-swift v1.x:**
```
https://github.com/grpc/grpc-swift.git
```
- Select version: Up to Next Major `1.23.1`
- Add products: `GRPC`, `NIO`, `NIOConcurrencyHelpers`

**swift-protobuf:**
```
https://github.com/apple/swift-protobuf.git
```
- Select version: `1.0.0` or later
- Add product: `SwiftProtobuf`

### 2. Add Generated Files to Xcode

The generated Swift files are in the `Generated/` directory:
- `common.pb.swift`
- `event.grpc.swift` / `event.pb.swift`
- `user.grpc.swift` / `user.pb.swift`
- `vendor.grpc.swift` / `vendor.pb.swift`
- `invitation.grpc.swift` / `invitation.pb.swift`

Drag these files into Xcode or add them via **File > Add Files to "RushDay"**.

### 3. Add GRPCClientService.swift

Add `GRPCClientService.swift` to your Xcode project.

## Usage

### Initialize the Client

```swift
import Foundation

// In your AppDelegate or App initialization
do {
    #if DEBUG
    try GRPCClientService.shared.connect(configuration: .development)
    #else
    try GRPCClientService.shared.connect(configuration: .production)
    #endif
} catch {
    print("Failed to connect to gRPC server: \(error)")
}
```

### Set Authentication Token

After Firebase authentication:

```swift
// Get Firebase ID token
let token = try await Auth.auth().currentUser?.getIDToken()
GRPCClientService.shared.setAuthToken(token)
```

### Make API Calls

All methods use async/await for clean, modern Swift code:

```swift
// Get current user
let user = try await GRPCClientService.shared.getCurrentUser()

// List events
let response = try await GRPCClientService.shared.listEvents(page: 1, limit: 20)
for event in response.events {
    print(event.name)
}

// Create an event
var request = Rushday_V1_CreateEventRequest()
request.name = "Birthday Party"
request.date = Google_Protobuf_Timestamp(date: Date())
let newEvent = try await GRPCClientService.shared.createEvent(request)

// Create a task
var taskRequest = Rushday_V1_CreateTaskRequest()
taskRequest.eventID = newEvent.id
taskRequest.name = "Book venue"
let task = try await GRPCClientService.shared.createTask(taskRequest)

// Toggle task done
let updatedTask = try await GRPCClientService.shared.toggleTaskDone(id: task.id)
```

## Regenerating Proto Files

If the backend proto files are updated:

1. Copy the new `.proto` files to `Proto/`
2. Run the generation script:

```bash
cd RushDay/Core/Services/GRPC/Proto
./generate.sh
```

**Prerequisites:**

The script uses grpc-swift v1.x plugin. To install:

```bash
# Install protobuf and swift-protobuf
brew install protobuf swift-protobuf

# Build and install grpc-swift v1.x plugin
cd /tmp
git clone --depth 1 --branch 1.23.1 https://github.com/grpc/grpc-swift.git
cd grpc-swift
swift build -c release --product protoc-gen-grpc-swift
mkdir -p ~/bin
cp .build/release/protoc-gen-grpc-swift ~/bin/protoc-gen-grpc-swift-1
```

## Configuration

### Development
- Host: `localhost`
- Port: `50051`
- TLS: Disabled

### Production
- Host: `api.rushday.app`
- Port: `443`
- TLS: Enabled

You can create custom configurations:

```swift
let customConfig = GRPCClientService.Configuration(
    host: "staging.rushday.app",
    port: 443,
    useTLS: true
)
try GRPCClientService.shared.connect(configuration: customConfig)
```

## Error Handling

```swift
do {
    let events = try await GRPCClientService.shared.listEvents()
} catch let error as GRPCError {
    switch error {
    case .notConnected:
        // Need to call connect() first
        break
    case .invalidResponse:
        // Server returned unexpected data
        break
    case .serverError(let message):
        // Handle server error
        print("Server error: \(message)")
    }
} catch let grpcStatus as GRPCStatus {
    switch grpcStatus.code {
    case .unauthenticated:
        // Token expired, re-authenticate
        break
    case .permissionDenied:
        // No access to resource
        break
    case .notFound:
        // Resource not found
        break
    default:
        print("gRPC error: \(grpcStatus.message ?? "Unknown")")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Why grpc-swift v1.x?

| Feature | v1.x | v2.x |
|---------|------|------|
| **iOS Support** | iOS 12+ | iOS 18+ |
| **Concurrency** | NIO + async/await bridge | Native async/await |
| **Stability** | Mature, production-ready | Newer, evolving |
| **API Style** | `.response.get()` | Native async |

Since your app targets iOS 17, v1.x is required. The API still supports async/await through NIO bridging, so the code is clean and modern.

## Requirements

- iOS 12+ (tested on iOS 17)
- Swift 5.5+
- Xcode 14.0+
