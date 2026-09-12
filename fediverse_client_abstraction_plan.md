# Implementation Plan: Fediverse Client Abstraction

## Architectural Objective
Replace the monolithic `MastodonClient` with a Strategy Pattern. The UI targets a generic `@Observable FediverseClient`. A factory injects a platform-specific `FediverseBackend` adapter (Mastodon, Misskey, Bluesky, IceShrimp) that handles proprietary authentication, REST interception, and DTO-to-Mastodon translation. 

---

## Phase 1: Core Shell & Protocol Extraction
**Goal:** Establish the interfaces and migrate the legacy Mastodon logic without breaking the app.

1. **Create `FediverseBackend.swift`:**
   Define the contract for all network adapters.
   ```swift
   public struct ServerCapabilities: Sendable {
       public var supportsAdvancedFilterContexts: Bool = true
       public var supportsEndorsements: Bool = true
       public var supportsLocalTimeline: Bool = true
       public var supportsPolls: Bool = true
       public var supportsFollowRequests: Bool = true
   }

   public protocol FediverseBackend: Sendable {
       var capabilities: ServerCapabilities { get }
       func oauthURL() async throws -> URL
       func continueOauthFlow(url: URL) async throws -> OauthToken
       func get<Entity: Decodable>(endpoint: Endpoint) async throws -> Entity
       func getWithLink<Entity: Decodable>(endpoint: Endpoint) async throws -> (Entity, LinkHandler?)
       func post(endpoint: Endpoint) async throws -> HTTPURLResponse?
       func openStream(for streams: [Stream]) async throws -> AsyncStream<any StreamEvent>
   }
   ```
2. **Extract `MastodonBackend.swift`:**
   Move all existing URLSession, JSONDecoder, and StreamEventDecoder logic from `MastodonClient` into this class. It acts as the default `FediverseBackend`.
3. **Refactor `MastodonClient` to `FediverseClient.swift`:**
   Convert the shell into a Factory that initializes the correct backend based on `AppAccount.serverSoftware`.
   Execute a global regex replacement across the codebase: `s/MastodonClient/FediverseClient/g`.

---

## Phase 2: IceShrimp Tech-Debt Sanitization
**Goal:** Remove IceShrimp-specific `if` checks from the global SwiftUI views and isolate them in a backend adapter.

1. **Model Mutability:**
   Change `MediaAttachment.type` from `let` to `var` in the `Models` package to permit data mutation before UI rendering.
2. **Implement `IceShrimpBackend.swift`:**
   Subclass `MastodonBackend` and override the `get()` method to intercept and patch known API failures:
   - **Trends API:** Intercept `Trends` endpoint and return an empty array to prevent 404s.
   - **Regex Engine:** Move the `applyIceShrimpFilters` execution inside the `get()` override.
   - **Media Types:** Iterate `MediaAttachments` on incoming `Status` objects. If `.mp4` is tagged as `image`, mutate `type = "video"`.
3. **UI Cleanup:**
   Delete all `isIceShrimp` variables from `GalleryStatusesListView.swift`, `StatusRowMediaPreviewView.swift`, and `Router.swift`. The UI now blindly trusts the `FediverseClient`.

---

## Phase 3: Cross-Spec Polyfills (Misskey & Bluesky)
**Goal:** Implement adapters that translate non-Mastodon REST structures into Mastodon DTOs.

### 1. Pagination Normalization
- **Issue:** Mastodon uses HTTP `Link` headers; Misskey/Bluesky use JSON `cursor` properties.
- **Implementation:** `MisskeyBackend.getWithLink()` extracts the JSON cursor, formats a fake HTTP `Link` header string (`<https://api?cursor=123>; rel="next"`), and returns it via `LinkHandler`. The UI paginates using its standard logic.

### 2. Search Aggregation
- **Issue:** Mastodon uses a unified `/search` route. Others fragment search by type.
- **Implementation:** When `FediverseClient` receives `Search.search(query:)`, `MisskeyBackend` executes `POST /users/search`, `POST /notes/search`, and `POST /hashtags/search` concurrently. It bundles the three DTO arrays into a single Mastodon `Search` struct and returns it.

### 3. Authentication Handshakes
- **MiAuth (Misskey):** `oauthURL()` generates a UUID and returns a fake OAuth URL for the browser. `continueOauthFlow()` polls the completion endpoint and translates it to `OauthToken`.
- **App Passwords (Bluesky):** `oauthURL()` throws `AuthError.requiresNativeLogin`. `AddAccountsView.swift` catches this and presents a native username/password form.

### 4. WebSocket Streaming
- **Issue:** Misskey uses proprietary JSON subscription commands that crash `StreamEventDecoder`.
- **Implementation:** `FediverseBackend` returns an `AsyncStream<any StreamEvent>`. `MisskeyBackend` manages the raw `URLSessionWebSocketTask` internally, handles the proprietary JSON handshakes, and yields standard `StreamEventUpdate` objects to the UI.

### 5. Bluesky AT Protocol Translation
- **Thread Contexts:** `BlueskyBackend` intercepts `GET /context`, executes a Depth-First Search on Bluesky's recursive thread tree, and flattens it into `ancestors` and `descendants` arrays.
- **Facet Rendering:** `Bluesky+Translate.swift` iterates over ATProto byte-offset Facets and directly injects Markdown links into the text string, bypassing the computationally expensive `SwiftSoup` HTML parser used by Mastodon.
