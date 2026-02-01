---
name: grpc-integration
description: Guides gRPC implementation, proto file generation, and backend integration for Rush Day iOS app. Auto-applies when working with proto files or gRPC services.
---

# gRPC Integration Guidelines

## Proto Files Location
`RushDay/Core/Services/GRPC/Proto/`

## Regenerate Swift Files
```bash
cd RushDay/Core/Services/GRPC/Proto && ./generate.sh
```

Generated files go to `Core/Services/GRPC/Generated/` (never edit manually).

## Proto Services

| File | Purpose |
|------|---------|
| `user.proto` | User management, migration |
| `event.proto` | Events, Tasks, Guests, Agenda, Budget |
| `vendor.proto` | Vendor listings |
| `invitation.proto` | Public invitation links |
| `ai_planner.proto` | AI event planning |
| `common.proto` | Shared types |

## Adding New RPC Methods

1. Add method to `.proto` file
2. Run `./generate.sh`
3. Add wrapper to `GRPCClientService.swift`
4. Add to protocol in `Domain/Repositories/Repositories.swift`
5. Implement in `Data/RepositoriesImpl/RepositoryImplementations.swift`

## Client Usage

```swift
let grpc = GRPCClientService.shared
grpc.setAuthToken(firebaseIdToken)

let events = try await grpc.listEvents()
let tasks = try await grpc.listTasks(eventId: eventId)
```

## Key Rule
Use gRPC for ALL data operations. Firebase is ONLY for Auth, Storage, FCM.
