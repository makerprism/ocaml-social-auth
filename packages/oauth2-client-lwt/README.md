# oauth2-client-lwt

Lwt runtime adapter for `oauth2-client` with Cohttp HTTP client.

> **Warning**
> This library is **not production-ready**. It was primarily built using LLMs and is still a work in progress. We are actively working towards making it stable and usable.

## Overview

This package provides a ready-to-use Lwt implementation of OAuth2 authentication flows. It includes:

- Cohttp_lwt_unix HTTP client implementation
- Unix-based cryptographically secure RNG (using /dev/urandom)
- Ready-to-use PKCE module (no need to create your own RNG)
- Lwt-friendly promise-based API
- Error handling with Lwt.catch
- Drop-in replacement for CPS-style callbacks

## Installation

```bash
opam install oauth2-client-lwt oauth2-google
```

## Quick Start

```ocaml
open Lwt.Syntax
open Oauth2_client_lwt

let authenticate_with_google () =
  (* Create Google config *)
  let config = Oauth2_google.make_config
    ~client_id:"your-client-id"
    ~client_secret:"your-client-secret"
    ~redirect_uri:"https://yourapp.com/callback"
    ()
  in
  
  (* Start authorization flow *)
  let (oauth_state, auth_url) = start_authorization_flow config in
  
  (* Store oauth_state in session/database *)
  (* Redirect user to auth_url *)
  
  Printf.printf "Visit: %s\n" auth_url;
  
  (* After user authorizes and you receive the callback... *)
  let code = "authorization-code-from-callback" in
  
  (* Complete the flow *)
  let* result = complete_oauth_flow
    config
    ~code
    ~code_verifier:oauth_state.code_verifier
    ~parse_user_info:Oauth2_google.parse_user_info
  in
  
  match result with
  | Ok (token_response, user_info) ->
      Printf.printf "Authenticated: %s\n" 
        (Option.value user_info.email ~default:"no email");
      Lwt.return_unit
  | Error err ->
      Printf.eprintf "Authentication failed: %s\n" err;
      Lwt.return_unit
```

## API

### Promise-Based Functions

All functions return `Lwt.t` promises with `(value, string) result`:

#### `start_authorization_flow`

```ocaml
val start_authorization_flow :
  provider_config ->
  oauth_state * string
```

Synchronous function (no Lwt) that generates state and authorization URL.

#### `complete_oauth_flow`

```ocaml
val complete_oauth_flow :
  provider_config ->
  code:string ->
  code_verifier:string ->
  parse_user_info:(string -> (user_info, string) result) ->
  ((token_response * user_info), string) result Lwt.t
```

Complete OAuth flow: exchange code for tokens and fetch user info.

#### `exchange_code_for_tokens`

```ocaml
val exchange_code_for_tokens :
  provider_config ->
  code:string ->
  code_verifier:string ->
  (token_response, string) result Lwt.t
```

Exchange authorization code for access token.

#### `refresh_access_token`

```ocaml
val refresh_access_token :
  provider_config ->
  refresh_token:string ->
  (token_response, string) result Lwt.t
```

Refresh an expired access token.

#### `get_user_info`

```ocaml
val get_user_info :
  provider_config ->
  access_token:string ->
  parse_user_info:(string -> (user_info, string) result) ->
  (user_info, string) result Lwt.t
```

Fetch user information using access token.

## Complete Example with Dream Web Framework

```ocaml
open Lwt.Syntax

let google_config = Oauth2_google.make_config
  ~client_id:(Sys.getenv "GOOGLE_CLIENT_ID")
  ~client_secret:(Sys.getenv "GOOGLE_CLIENT_SECRET")
  ~redirect_uri:"http://localhost:8080/auth/google/callback"
  ()

(* Start OAuth flow *)
let google_login_handler _req =
  let (oauth_state, auth_url) = Oauth2_client_lwt.start_authorization_flow google_config in
  
  (* Store oauth_state in session *)
  (* In real app: store in database or encrypted cookie *)
  Dream.set_session_field _req "oauth_state" 
    (oauth_state.state ^ "|" ^ oauth_state.code_verifier);
  
  Dream.redirect _req auth_url

(* Handle OAuth callback *)
let google_callback_handler req =
  let code = Dream.query req "code" in
  let state = Dream.query req "state" in
  
  match (code, state) with
  | (Some code, Some state) ->
      let* stored_state = Dream.session_field req "oauth_state" in
      (match stored_state with
      | Some stored ->
          let parts = String.split_on_char '|' stored in
          (match parts with
          | [stored_state; code_verifier] when stored_state = state ->
              let* result = Oauth2_client_lwt.complete_oauth_flow
                google_config
                ~code
                ~code_verifier
                ~parse_user_info:Oauth2_google.parse_user_info
              in
              (match result with
              | Ok (token, user_info) ->
                  (* Store user session *)
                  Dream.set_session_field req "user_id" user_info.provider_user_id;
                  Dream.html (Printf.sprintf "Welcome %s!" 
                    (Option.value user_info.name ~default:"User"))
              | Error err ->
                  Dream.html ~status:`Bad_Request 
                    (Printf.sprintf "Auth failed: %s" err))
          | _ ->
              Dream.html ~status:`Bad_Request "Invalid state")
      | None ->
          Dream.html ~status:`Bad_Request "No session")
  | _ ->
      Dream.html ~status:`Bad_Request "Missing code or state"

let () =
  Dream.run
  @@ Dream.logger
  @@ Dream.memory_sessions
  @@ Dream.router [
    Dream.get "/login/google" google_login_handler;
    Dream.get "/auth/google/callback" google_callback_handler;
  ]
```

## Error Handling

All functions return `result Lwt.t` for explicit error handling:

```ocaml
let* result = Oauth2_client_lwt.exchange_code_for_tokens config ~code ~code_verifier in
match result with
| Ok token ->
    (* Success *)
    Printf.printf "Access token: %s\n" token.access_token;
    Lwt.return_unit
| Error err ->
    (* Handle error *)
    Printf.eprintf "Token exchange failed: %s\n" err;
    Lwt.return_unit
```

## Using with Multiple Providers

```ocaml
let authenticate_user provider_type =
  let config = match provider_type with
    | `Google ->
        Oauth2_google.make_config
          ~client_id:(Sys.getenv "GOOGLE_CLIENT_ID")
          ~client_secret:(Sys.getenv "GOOGLE_CLIENT_SECRET")
          ~redirect_uri:"http://localhost:8080/callback"
          ()
    | `GitHub ->
        Oauth2_github.make_config
          ~client_id:(Sys.getenv "GITHUB_CLIENT_ID")
          ~client_secret:(Sys.getenv "GITHUB_CLIENT_SECRET")
          ~redirect_uri:"http://localhost:8080/callback"
          ()
  in
  
  let parse_user_info = match provider_type with
    | `Google -> Oauth2_google.parse_user_info
    | `GitHub -> Oauth2_github.parse_user_info
  in
  
  let (oauth_state, auth_url) = Oauth2_client_lwt.start_authorization_flow config in
  (* ... rest of flow *)
```

## HTTP Client

The package uses `cohttp-lwt-unix` for HTTP requests. If you need a different HTTP client, you can implement the `HTTP_CLIENT` interface from `oauth2-client` directly.

## RNG Implementation

This package provides a Unix-based RNG implementation that reads from `/dev/urandom`, which is available on Linux, macOS, and BSD systems. The RNG is used internally by the `Pkce` module.

If you need a different RNG (e.g., for Windows or cross-platform support), you can create your own using `Oauth2_client.Make_pkce` with a custom RNG implementation.

## Re-exported Types

For convenience, all core types are re-exported in the `Types` module:

```ocaml
open Oauth2_client_lwt.Types

let user : user_info = ...
let token : token_response = ...
let state : oauth_state = ...
```

## License

MIT
