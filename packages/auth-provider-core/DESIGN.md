# auth-provider-core Design Document

## Overview

`auth-provider-core` is a runtime-agnostic, HTTP-client-agnostic OAuth2 authentication library for OCaml. It provides the foundation for building secure OAuth2 login flows with any identity provider.

## Architecture Decisions

### 1. Runtime Agnostic (CPS Style)

**Decision**: Use continuation-passing style (CPS) for all async operations

**Rationale**:
- Works with **any async runtime**: Lwt, Eio, synchronous code
- No dependencies on specific runtime libraries
- More flexible for library consumers
- Similar pattern to `social-provider-core`

**Example**:
```ocaml
val exchange_code_for_tokens :
  config ->
  code:string ->
  code_verifier:string ->
  on_success:(token_response -> unit) ->
  on_error:(string -> unit) ->
  unit
```

### 2. HTTP Client Agnostic

**Decision**: Abstract HTTP client behind a simple interface

**Rationale**:
- Consumers can use Cohttp, Httpaf, Curly, or any other client
- Reduces dependency footprint
- Easier to test with mock HTTP clients
- Follows social-provider-core pattern

**Interface**:
```ocaml
module type HTTP_CLIENT = sig
  val post : 
    url:string ->
    headers:(string * string) list -> 
    body:string -> 
    on_success:(http_response -> unit) -> 
    on_error:(string -> unit) -> 
    unit
  
  val get : 
    url:string ->
    headers:(string * string) list -> 
    on_success:(http_response -> unit) -> 
    on_error:(string -> unit) -> 
    unit
end
```

### 3. PKCE by Default

**Decision**: All OAuth2 flows use PKCE (Proof Key for Code Exchange)

**Rationale**:
- **Security**: Prevents authorization code interception attacks
- **Modern standard**: Required for mobile/SPA apps, recommended for all apps
- **Client-secret-free**: Works without client secrets (better for public clients)
- **RFC 7636 compliance**

**Implementation**:
- `code_verifier`: 128 characters (maximum entropy)
- `code_challenge`: SHA256(code_verifier), base64-url encoded
- Validates RFC 7636 requirements (43-128 unreserved characters)

### 4. Modular Package Structure

**Decision**: Core package + provider-specific packages

**Packages**:
```
auth-provider-core/          # Core abstractions (this package)
auth-provider-lwt/           # Lwt runtime adapter (future)
auth-provider-google-v2/     # Google OAuth (future)
auth-provider-github-v2/     # GitHub OAuth (future)
```

**Rationale**:
- Core package has zero runtime dependencies
- Consumers only install what they need
- Easy to add new providers
- Matches social-provider-* pattern

### 5. Provider-Specific Parsing

**Decision**: User info parsing is provider-specific, not in core

**Rationale**:
- Each provider has different JSON response structure
- Core library stays minimal and focused
- Providers can include custom fields in `raw_response`
- Easier to version providers independently

**Example**:
```ocaml
(* In auth-provider-google-v2 *)
let parse_user_info json_body =
  (* Google-specific JSON parsing *)
  { provider = Google;
    provider_user_id = ...;
    email = ...;
    raw_response = json; (* Full response for custom fields *)
  }
```

### 6. OpenID Connect Support

**Decision**: Include `id_token` field in token response

**Rationale**:
- Many providers (Google, Microsoft) support OpenID Connect
- ID token contains signed user claims
- Optional field (None for pure OAuth2 providers)
- Future-proof for OIDC features

### 7. Type Safety and Errors

**Decision**: Use result types and structured error handling

**Rationale**:
- Explicit error handling (no exceptions in core logic)
- OAuth errors are structured (error code + description)
- Type-safe provider identifiers
- Clear success/failure paths

**Types**:
```ocaml
type ('ok, 'err) result = Ok of 'ok | Error of 'err

type oauth_error = {
  error : string;
  error_description : string option;
  error_uri : string option;
}
```

## Module Structure

```
auth-provider-core/
├── auth_types.ml          # Core type definitions
│   ├── provider           # Provider enum (Google, GitHub, etc.)
│   ├── token_response     # OAuth2 token response
│   ├── user_info          # User information from provider
│   ├── oauth_state        # CSRF state + PKCE verifier
│   ├── provider_config    # OAuth2 configuration
│   └── http_response      # HTTP abstraction
├── pkce.ml                # PKCE implementation (RFC 7636)
│   ├── generate_code_verifier
│   ├── generate_code_challenge
│   └── generate_state
├── oauth2_flow.ml         # OAuth2 flow logic
│   ├── HTTP_CLIENT        # Interface definition
│   ├── build_authorization_url
│   ├── exchange_code_for_tokens
│   ├── refresh_access_token
│   └── get_user_info
└── auth_provider_core.ml  # Main module (re-exports)
```

## Key Features

### 1. Complete OAuth2 Flow

```ocaml
(* 1. Start authorization *)
let (oauth_state, auth_url) = start_authorization_flow config

(* 2. User authorizes at provider *)
(* Redirect user to auth_url *)

(* 3. Handle callback *)
complete_oauth_flow config ~code ~code_verifier ~parse_user_info
  ~on_success:(fun (token_response, user_info) -> ...)
  ~on_error:(fun err -> ...)
```

### 2. Token Refresh

```ocaml
refresh_access_token config ~refresh_token
  ~on_success:(fun token_response -> ...)
  ~on_error:(fun err -> ...)
```

### 3. Custom Provider Support

```ocaml
type provider = 
  | Google
  | GitHub
  | Microsoft
  | Custom of string  (* Support any OAuth2 provider *)
```

## Security Features

1. **PKCE**: All flows use code_verifier and code_challenge
2. **CSRF Protection**: State parameter validated on callback
3. **Secure Random**: Uses cryptographically secure RNG
4. **Token Expiration**: Tracks expires_at timestamps
5. **No Client Secret Required**: Pure PKCE works without secrets

## Comparison with Existing Code

### Before (backend/lib/infra/oauth2_*)
- ❌ Lwt-dependent
- ❌ Cohttp-dependent
- ❌ Tightly coupled to Dream web framework
- ❌ Not reusable outside FeedMansion
- ✅ Works, but monolithic

### After (packages/auth-provider-core)
- ✅ Runtime-agnostic (Lwt, Eio, sync)
- ✅ HTTP-client-agnostic
- ✅ Framework-agnostic
- ✅ Publishable to opam
- ✅ Modular and testable
- ✅ Follows social-provider-* pattern

## Next Steps

1. **Provider Packages**: Create `auth-provider-google-v2`
2. **Lwt Adapter**: Create `auth-provider-lwt` with Cohttp implementation
3. **Migration**: Refactor existing backend code to use new library
4. **Tests**: Add comprehensive test suite
5. **Documentation**: API docs, examples, migration guide
6. **Publish**: Submit to opam-repository

## Design Principles

1. **Minimal Dependencies**: Only yojson, digestif, base64
2. **Type Safety**: Explicit types, no magic strings
3. **Security First**: PKCE by default, proper randomness
4. **Flexibility**: Works with any runtime/HTTP client
5. **Standards Compliance**: RFC 6749, RFC 7636, OpenID Connect
6. **Pragmatic**: Simple API, clear error messages

## Influences

- `social-provider-core`: CPS style, runtime-agnostic design
- `cohttp`: Minimal HTTP abstractions
- `dream`: Security-first approach
- OAuth2 RFCs: Standards compliance
