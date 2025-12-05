# ocaml-social-auth

Runtime-agnostic OAuth 2.0 authentication libraries for OCaml. Supports GitHub, Google, Microsoft/Azure AD with PKCE. Works with any HTTP client and async runtime (Lwt, Eio).

## Packages

| Package | Description |
|---------|-------------|
| `auth-provider-core` | Core OAuth2/PKCE abstractions (runtime-agnostic) |
| `auth-provider-lwt` | Lwt runtime adapter |
| `auth-provider-github-v2` | GitHub OAuth |
| `auth-provider-google-v2` | Google OAuth/OpenID Connect |
| `auth-provider-microsoft-v2` | Microsoft/Azure AD OAuth |

## Installation

### Using Dune Package Management (recommended)

Add to your `dune-project`:

```scheme
(pin
 (url "git+https://github.com/makerprism/ocaml-social-auth")
 (package (name auth-provider-core)))

(pin
 (url "git+https://github.com/makerprism/ocaml-social-auth")
 (package (name auth-provider-lwt)))

(pin
 (url "git+https://github.com/makerprism/ocaml-social-auth")
 (package (name auth-provider-github-v2)))
```

Then run:
```bash
dune pkg lock
dune build
```

## Usage

### Basic OAuth2 Flow with GitHub

```ocaml
open Auth_provider_core
open Auth_provider_github_v2

(* Create a GitHub provider *)
let github = Github.create
  ~client_id:"your_client_id"
  ~client_secret:"your_client_secret"
  ~redirect_uri:"http://localhost:8080/callback"
  ()

(* Generate authorization URL with PKCE *)
let auth_url, code_verifier = Github.authorization_url github
  ~scopes:["user:email"; "read:user"]
  ()

(* After user authorizes, exchange code for tokens *)
let tokens = Github.exchange_code github
  ~code:"authorization_code_from_callback"
  ~code_verifier
  ()
```

### With Lwt Runtime

```ocaml
open Auth_provider_lwt

let%lwt tokens = 
  Auth_lwt.exchange_code github ~code ~code_verifier ()
```

## Architecture

The library follows a runtime-agnostic design:

1. **Core** (`auth-provider-core`): Pure OCaml types and interfaces, no IO
2. **Runtime Adapters** (`auth-provider-lwt`): Concrete implementations for specific runtimes
3. **Providers** (`auth-provider-*-v2`): Platform-specific OAuth implementations

This design allows you to:
- Use the same provider logic with different async runtimes
- Easily test with mock HTTP clients
- Swap out HTTP implementations without changing business logic

## License

MIT
