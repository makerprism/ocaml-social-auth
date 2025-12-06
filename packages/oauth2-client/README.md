# oauth2-client

Runtime-agnostic OAuth2 client library with PKCE support for OCaml.

> **Warning**
> This library is **not production-ready**. It was primarily built using LLMs and is still a work in progress. We are actively working towards making it stable and usable.

## Overview

`oauth2-client` provides a clean, runtime-agnostic interface for implementing OAuth2 authentication flows. It supports:

- **OAuth 2.0 with PKCE** (Proof Key for Code Exchange) for maximum security
- **Runtime-agnostic**: Works with Lwt, Eio, or synchronous code
- **HTTP-client-agnostic**: Use any HTTP client library (Cohttp, Httpaf, etc.)
- **Provider-independent**: Core abstractions that work with any OAuth2 provider
- **OpenID Connect compatible**: Includes support for ID tokens

## Key Features

- PKCE support (RFC 7636) for secure authorization code flow
- Continuation-passing style (CPS) for runtime flexibility
- Token refresh support
- Comprehensive type safety
- Minimal dependencies (only yojson, digestif, base64)
- Pluggable RNG - bring your own cryptographically secure random number generator

## Installation

```bash
opam install oauth2-client
```

## Usage

### 1. Define Your HTTP Client

First, implement the `HTTP_CLIENT` interface for your runtime:

```ocaml
module Lwt_http_client : Oauth2_client.HTTP_CLIENT = struct
  open Lwt.Syntax
  
  let post ~url ~headers ~body ~on_success ~on_error =
    Lwt.async (fun () ->
      let open Cohttp in
      let open Cohttp_lwt_unix in
      let headers = Header.of_list headers in
      let* (resp, body) = Client.post 
        ~headers 
        ~body:(Cohttp_lwt.Body.of_string body)
        (Uri.of_string url) 
      in
      let* body_str = Cohttp_lwt.Body.to_string body in
      let status = Response.status resp |> Code.code_of_status in
      let response = {
        Oauth2_client.status;
        headers = Header.to_list (Response.headers resp);
        body = body_str;
      } in
      on_success response;
      Lwt.return_unit
    )
  
  let get ~url ~headers ~on_success ~on_error =
    (* Similar implementation for GET *)
    (* ... *)
end
```

### 2. Create Provider-Specific Parser

```ocaml
(* Google user info parser *)
let parse_google_user_info json_body =
  try
    let open Yojson.Basic.Util in
    let json = Yojson.Basic.from_string json_body in
    let user_info = Oauth2_client.{
      provider = Google;
      provider_user_id = json |> member "id" |> to_string;
      email = json |> member "email" |> to_string_option;
      email_verified = json |> member "email_verified" |> to_bool_option;
      name = json |> member "name" |> to_string_option;
      given_name = json |> member "given_name" |> to_string_option;
      family_name = json |> member "family_name" |> to_string_option;
      username = None;
      avatar_url = json |> member "picture" |> to_string_option;
      locale = json |> member "locale" |> to_string_option;
      raw_response = json;
    } in
    Ok user_info
  with e ->
    Error (Printf.sprintf "Failed to parse user info: %s" (Printexc.to_string e))
```

### 3. Define Your RNG

The library requires a cryptographically secure RNG. Implement the `RNG` interface:

```ocaml
(* Using /dev/urandom directly *)
module Unix_rng : Oauth2_client.RNG = struct
  let generate n =
    let fd = Unix.openfile "/dev/urandom" [Unix.O_RDONLY] 0 in
    let buf = Bytes.create n in
    let _ = Unix.read fd buf 0 n in
    Unix.close fd;
    buf
end

(* Or use mirage-crypto-rng *)
module Mirage_rng : Oauth2_client.RNG = struct
  let generate n =
    let cs = Mirage_crypto_rng.generate n in
    (* Convert Cstruct to bytes - API varies by version *)
    Cstruct.to_bytes cs
end
```

### 4. Create PKCE and OAuth2 Flow Modules

```ocaml
module Pkce = Oauth2_client.Make_pkce(Unix_rng)
module Google_oauth = Oauth2_client.Make_oauth2_flow(Lwt_http_client)(Pkce)

(* Create provider config *)
let config = {
  Oauth2_client.
  client_id = "your-client-id";
  client_secret = Some "your-client-secret";
  redirect_uri = "https://yourapp.com/auth/callback";
  scopes = [
    "openid";
    "https://www.googleapis.com/auth/userinfo.email";
    "https://www.googleapis.com/auth/userinfo.profile";
  ];
  auth_endpoint = "https://accounts.google.com/o/oauth2/v2/auth";
  token_endpoint = "https://oauth2.googleapis.com/token";
  user_info_endpoint = "https://www.googleapis.com/oauth2/v2/userinfo";
  extra_auth_params = [];
}

(* Start authorization flow *)
let (oauth_state, auth_url) = Google_oauth.start_authorization_flow config

(* Redirect user to auth_url *)
(* Store oauth_state securely (database, session, etc.) *)

(* Handle callback *)
let handle_callback ~code ~state =
  (* Retrieve stored oauth_state by state token *)
  (* Validate state matches *)
  
  Google_oauth.complete_oauth_flow 
    config 
    ~code 
    ~code_verifier:oauth_state.code_verifier
    ~parse_user_info:parse_google_user_info
    ~on_success:(fun (token_response, user_info) ->
      (* User authenticated! *)
      (* Create session, store tokens, etc. *)
    )
    ~on_error:(fun err ->
      (* Handle error *)
    )
```

## Architecture

### Runtime Agnostic Design

The library uses **continuation-passing style (CPS)** to remain runtime-agnostic:

```ocaml
val exchange_code_for_tokens :
  config ->
  code:string ->
  code_verifier:string ->
  on_success:(token_response -> unit) ->
  on_error:(string -> unit) ->
  unit
```

This means you can use it with:
- **Lwt**: Wrap callbacks in `Lwt.async`
- **Eio**: Use Eio fibers
- **Synchronous**: Use regular blocking calls

### Security Features

1. **PKCE (RFC 7636)**: All flows use PKCE to prevent authorization code interception
2. **CSRF Protection**: State parameter validates callback authenticity
3. **No Client Secret Required**: Pure PKCE flows work without client secrets (mobile/SPA apps)
4. **Token Expiration**: Automatic expiration tracking
5. **Pluggable RNG**: Users provide their own cryptographically secure RNG implementation

### Pluggable RNG

The library does not bundle a cryptographic RNG to minimize dependencies. Instead, you provide your own implementation of the `RNG` module type:

```ocaml
module type RNG = sig
  val generate : int -> bytes
end
```

This allows you to use:
- `/dev/urandom` or `getrandom()` system calls
- `mirage-crypto-rng` for cross-platform support
- Any other cryptographically secure source

**Note**: If you use `oauth2-client-lwt`, it provides a ready-to-use Unix-based RNG implementation.

## Package Structure

```
oauth2-client/
├── lib/
│   ├── auth_types.ml          # Core type definitions
│   ├── pkce.ml                # PKCE implementation (RFC 7636)
│   ├── oauth2_flow.ml         # OAuth2 flow logic
│   └── oauth2_client.ml       # Main module
├── dune-project
└── README.md
```

## Related Packages

- `oauth2-client-lwt` - Lwt runtime adapter
- `oauth2-google` - Google OAuth provider
- `oauth2-github` - GitHub OAuth provider
- `oauth2-microsoft` - Microsoft/Azure AD OAuth provider

## Standards Compliance

- [RFC 6749](https://tools.ietf.org/html/rfc6749) - OAuth 2.0 Authorization Framework
- [RFC 7636](https://tools.ietf.org/html/rfc7636) - PKCE
- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)

## Contributing

Contributions welcome! Please see the [contributing guide](../../CONTRIBUTING.md) for details.

## License

MIT
