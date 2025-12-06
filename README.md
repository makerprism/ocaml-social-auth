# ocaml-oauth2-clients

[![CI](https://github.com/makerprism/ocaml-oauth2-clients/actions/workflows/ci.yml/badge.svg)](https://github.com/makerprism/ocaml-oauth2-clients/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OCaml](https://img.shields.io/badge/OCaml-%3E%3D4.14-orange)](https://ocaml.org/)

> **Warning**
> These libraries are **not production-ready**. They were primarily built using LLMs and are still a work in progress. We are actively working towards making them stable and usable.
>
> **Current status:** Only Google OAuth login has been used successfully in an app we are developing. Other providers (GitHub, Microsoft) should be considered experimental.

Runtime-agnostic OAuth 2.0 client libraries for OCaml. Supports GitHub, Google, Microsoft/Azure AD with PKCE. Works with any HTTP client and async runtime (Lwt, Eio).

## Packages

| Package | Description |
|---------|-------------|
| `oauth2-client` | Core OAuth2/PKCE abstractions (runtime-agnostic) |
| `oauth2-client-lwt` | Lwt runtime adapter |
| `oauth2-github` | GitHub OAuth |
| `oauth2-google` | Google OAuth/OpenID Connect |
| `oauth2-microsoft` | Microsoft/Azure AD OAuth |

## Installation

### Using Dune Package Management (recommended)

Add to your `dune-project`:

```scheme
(pin
 (url "git+https://github.com/makerprism/ocaml-oauth2-clients")
 (package (name oauth2-client)))

(pin
 (url "git+https://github.com/makerprism/ocaml-oauth2-clients")
 (package (name oauth2-client-lwt)))

(pin
 (url "git+https://github.com/makerprism/ocaml-oauth2-clients")
 (package (name oauth2-github)))
```

Then run:
```bash
dune pkg lock
dune build
```

## Usage

### Basic OAuth2 Flow with GitHub

```ocaml
open Oauth2_client
open Oauth2_github

(* Create a GitHub provider *)
let github = Oauth2_github.make_config
  ~client_id:"your_client_id"
  ~client_secret:"your_client_secret"
  ~redirect_uri:"http://localhost:8080/callback"
  ()

(* Generate authorization URL with PKCE *)
let (oauth_state, auth_url) = Oauth2_client_lwt.start_authorization_flow github

(* After user authorizes, exchange code for tokens *)
let tokens = Oauth2_client_lwt.exchange_code_for_tokens github
  ~code:"authorization_code_from_callback"
  ~code_verifier:oauth_state.code_verifier
```

### With Lwt Runtime

```ocaml
open Oauth2_client_lwt

let%lwt result = 
  complete_oauth_flow github 
    ~code 
    ~code_verifier 
    ~parse_user_info:Oauth2_github.parse_user_info
```

## Architecture

The library follows a runtime-agnostic design:

1. **Core** (`oauth2-client`): Pure OCaml types and interfaces, no IO
2. **Runtime Adapters** (`oauth2-client-lwt`): Concrete implementations for specific runtimes
3. **Providers** (`oauth2-*`): Platform-specific OAuth implementations

This design allows you to:
- Use the same provider logic with different async runtimes
- Easily test with mock HTTP clients
- Swap out HTTP implementations without changing business logic

## License

MIT
