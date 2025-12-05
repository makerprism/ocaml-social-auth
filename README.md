# ocaml-social-auth

[![CI](https://github.com/makerprism/ocaml-social-auth/actions/workflows/ci.yml/badge.svg)](https://github.com/makerprism/ocaml-social-auth/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OCaml](https://img.shields.io/badge/OCaml-%3E%3D4.14-orange)](https://ocaml.org/)

> **Warning**
> These libraries are **not production-ready**. They were primarily built using LLMs and are still a work in progress. We are actively working towards making them stable and usable.
>
> **Current status:** Only Google OAuth login has been used successfully in an app we are developing. Other providers (GitHub, Microsoft) should be considered experimental.

Runtime-agnostic OAuth 2.0 authentication libraries for OCaml. Supports GitHub, Google, Microsoft/Azure AD with PKCE. Works with any HTTP client and async runtime (Lwt, Eio).

## Packages

| Package | Description |
|---------|-------------|
| `social-auth-core` | Core OAuth2/PKCE abstractions (runtime-agnostic) |
| `social-auth-lwt` | Lwt runtime adapter |
| `social-auth-github-v2` | GitHub OAuth |
| `social-auth-google-v2` | Google OAuth/OpenID Connect |
| `social-auth-microsoft-v2` | Microsoft/Azure AD OAuth |

## Installation

### Using Dune Package Management (recommended)

Add to your `dune-project`:

```scheme
(pin
 (url "git+https://github.com/makerprism/ocaml-social-auth")
 (package (name social-auth-core)))

(pin
 (url "git+https://github.com/makerprism/ocaml-social-auth")
 (package (name social-auth-lwt)))

(pin
 (url "git+https://github.com/makerprism/ocaml-social-auth")
 (package (name social-auth-github-v2)))
```

Then run:
```bash
dune pkg lock
dune build
```

## Usage

### Basic OAuth2 Flow with GitHub

```ocaml
open Social_auth_core
open Social_auth_github_v2

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
open Social_auth_lwt

let%lwt tokens = 
  Auth_lwt.exchange_code github ~code ~code_verifier ()
```

## Architecture

The library follows a runtime-agnostic design:

1. **Core** (`social-auth-core`): Pure OCaml types and interfaces, no IO
2. **Runtime Adapters** (`social-auth-lwt`): Concrete implementations for specific runtimes
3. **Providers** (`social-auth-*-v2`): Platform-specific OAuth implementations

This design allows you to:
- Use the same provider logic with different async runtimes
- Easily test with mock HTTP clients
- Swap out HTTP implementations without changing business logic

## License

MIT
