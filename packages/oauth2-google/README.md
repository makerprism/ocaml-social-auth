# oauth2-google

Google OAuth2 provider for `oauth2-client`.

> **Warning**
> This library is **not production-ready**. It was primarily built using LLMs and is still a work in progress. We are actively working towards making it stable and usable.
>
> **Current status:** Google OAuth login has been used successfully in an app we are developing.

## Overview

This package provides Google-specific OAuth2 configuration and user info parsing for use with `oauth2-client`. It implements:

- Google OAuth 2.0 with PKCE
- OpenID Connect support
- Email and profile scope handling
- Proper Google userinfo v2 API parsing

## Installation

```bash
opam install oauth2-google
```

## Quick Start

### 1. Create Google OAuth App

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable "Google+ API" or "People API"
4. Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client ID"
5. Configure OAuth consent screen
6. Add authorized redirect URI (e.g., `https://yourapp.com/auth/google/callback`)
7. Copy Client ID and Client Secret

### 2. Use with oauth2-client

```ocaml
(* Create Google config *)
let google_config = Oauth2_google.make_config
  ~client_id:"your-client-id.apps.googleusercontent.com"
  ~client_secret:"your-client-secret"
  ~redirect_uri:"https://yourapp.com/auth/google/callback"
  ()

(* Create OAuth flow with your HTTP client *)
module Google_auth = Oauth2_client.Make_oauth2_flow(Your_http_client)

(* Start authorization *)
let (oauth_state, auth_url) = Google_auth.start_authorization_flow google_config

(* Redirect user to auth_url *)
(* Store oauth_state in session/database *)

(* Handle callback *)
let handle_google_callback ~code ~state =
  (* Retrieve oauth_state by state parameter *)
  
  Google_auth.complete_oauth_flow
    google_config
    ~code
    ~code_verifier:oauth_state.code_verifier
    ~parse_user_info:Oauth2_google.parse_user_info
    ~on_success:(fun (token_response, user_info) ->
      (* User authenticated! *)
      Printf.printf "User: %s\n" (Option.value user_info.email ~default:"no email");
      Printf.printf "Google ID: %s\n" user_info.provider_user_id;
    )
    ~on_error:(fun err ->
      Printf.eprintf "Auth failed: %s\n" err
    )
```

## Configuration Options

### Default Scopes

By default, the provider requests:
- `openid` - OpenID Connect
- `https://www.googleapis.com/auth/userinfo.email` - User's email
- `https://www.googleapis.com/auth/userinfo.profile` - User's profile (name, picture)

### Custom Scopes

```ocaml
let config = Oauth2_google.make_config
  ~client_id:"..."
  ~client_secret:"..."
  ~redirect_uri:"..."
  ~scopes:[
    "openid";
    "https://www.googleapis.com/auth/userinfo.email";
    "https://www.googleapis.com/auth/userinfo.profile";
    (* Add additional scopes *)
    "https://www.googleapis.com/auth/calendar.readonly";
  ]
  ()
```

### Refresh Tokens

To get a refresh token, modify the config:

```ocaml
let google_config = 
  let base_config = Oauth2_google.make_config
    ~client_id:"..."
    ~client_secret:"..."
    ~redirect_uri:"..."
    ()
  in
  { base_config with
    extra_auth_params = [
      ("access_type", "offline");  (* Request refresh token *)
      ("prompt", "consent");        (* Force consent screen *)
    ];
  }
```

## User Info Fields

The `parse_user_info` function extracts:

| Field | Type | Description |
|-------|------|-------------|
| `provider` | `provider` | Always `Google` |
| `provider_user_id` | `string` | Google user ID |
| `email` | `string option` | User's email address |
| `email_verified` | `bool option` | Whether email is verified |
| `name` | `string option` | Full name |
| `given_name` | `string option` | First name |
| `family_name` | `string option` | Last name |
| `username` | `string option` | Always `None` (Google doesn't provide) |
| `avatar_url` | `string option` | Profile picture URL |
| `locale` | `string option` | User's locale (e.g., "en") |
| `raw_response` | `Yojson.Basic.t` | Full JSON for custom fields |

## Complete Example with Lwt

```ocaml
open Lwt.Syntax

(* Define HTTP client *)
module Lwt_http_client = struct
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
      let response = Oauth2_client.{
        status;
        headers = Header.to_list (Response.headers resp);
        body = body_str;
      } in
      on_success response;
      Lwt.return_unit
    )
  
  let get ~url ~headers ~on_success ~on_error =
    Lwt.async (fun () ->
      let open Cohttp in
      let open Cohttp_lwt_unix in
      let headers = Header.of_list headers in
      let* (resp, body) = Client.get 
        ~headers 
        (Uri.of_string url) 
      in
      let* body_str = Cohttp_lwt.Body.to_string body in
      let status = Response.status resp |> Code.code_of_status in
      let response = Oauth2_client.{
        status;
        headers = Header.to_list (Response.headers resp);
        body = body_str;
      } in
      on_success response;
      Lwt.return_unit
    )
end

module Google_auth = Oauth2_client.Make_oauth2_flow(Lwt_http_client)

let authenticate () =
  let config = Oauth2_google.make_config
    ~client_id:(Sys.getenv "GOOGLE_CLIENT_ID")
    ~client_secret:(Sys.getenv "GOOGLE_CLIENT_SECRET")
    ~redirect_uri:"http://localhost:8080/auth/google/callback"
    ()
  in
  
  let (oauth_state, auth_url) = Google_auth.start_authorization_flow config in
  
  Printf.printf "Visit: %s\n" auth_url;
  Printf.printf "Enter authorization code: ";
  flush stdout;
  
  let code = read_line () in
  
  let promise, resolver = Lwt.wait () in
  
  Google_auth.complete_oauth_flow
    config
    ~code
    ~code_verifier:oauth_state.code_verifier
    ~parse_user_info:Oauth2_google.parse_user_info
    ~on_success:(fun (token, user) ->
      Lwt.wakeup resolver (Ok (token, user))
    )
    ~on_error:(fun err ->
      Lwt.wakeup resolver (Error err)
    );
  
  promise
```

## API Reference

### `make_config`

```ocaml
val make_config :
  client_id:string ->
  client_secret:string ->
  redirect_uri:string ->
  ?scopes:string list ->
  unit ->
  Oauth2_client.provider_config
```

Create Google OAuth2 configuration.

### `parse_user_info`

```ocaml
val parse_user_info : 
  string -> 
  (Oauth2_client.user_info, string) result
```

Parse Google userinfo JSON response.

### `validate_scopes`

```ocaml
val validate_scopes : string list -> (unit, string) result
```

Validate that required scopes are present.

## Google OAuth2 Documentation

- [Google Identity Platform](https://developers.google.com/identity)
- [OAuth 2.0 for Web Server Applications](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Google API Scopes](https://developers.google.com/identity/protocols/oauth2/scopes)

## License

MIT
