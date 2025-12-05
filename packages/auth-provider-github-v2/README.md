# auth-provider-github-v2

GitHub OAuth2 authentication provider for `auth-provider-core`.

> **Warning**
> This library is **not production-ready**. It was primarily built using LLMs and is still a work in progress. We are actively working towards making it stable and usable.
>
> **Current status:** This provider has not been tested yet and should be considered experimental.

## Overview

This package provides GitHub-specific OAuth2 configuration and user info parsing for use with `auth-provider-core`. It implements:

- ✅ GitHub OAuth 2.0 with PKCE
- ✅ User profile retrieval
- ✅ Email and username access
- ✅ Proper GitHub API v3 integration

## Installation

```bash
opam install auth-provider-github-v2
```

## Quick Start

### 1. Create GitHub OAuth App

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Click "New OAuth App"
3. Fill in application details
4. Set Authorization callback URL (e.g., `https://yourapp.com/auth/github/callback`)
5. Copy Client ID and Client Secret

### 2. Use with auth-provider-core

```ocaml
(* Create GitHub config *)
let github_config = Auth_provider_github_v2.make_config
  ~client_id:"your-github-client-id"
  ~client_secret:"your-github-client-secret"
  ~redirect_uri:"https://yourapp.com/auth/github/callback"
  ()

(* Create OAuth flow with your HTTP client *)
module GitHub_auth = Auth_provider_core.Make_oauth2_flow(Your_http_client)

(* Start authorization *)
let (oauth_state, auth_url) = GitHub_auth.start_authorization_flow github_config

(* Redirect user to auth_url *)
(* Store oauth_state in session/database *)

(* Handle callback *)
let handle_github_callback ~code ~state =
  (* Retrieve oauth_state by state parameter *)
  
  GitHub_auth.complete_oauth_flow
    github_config
    ~code
    ~code_verifier:oauth_state.code_verifier
    ~parse_user_info:Auth_provider_github_v2.parse_user_info
    ~on_success:(fun (token_response, user_info) ->
      (* User authenticated! *)
      Printf.printf "User: %s\n" (Option.value user_info.username ~default:"no username");
      Printf.printf "GitHub ID: %s\n" user_info.provider_user_id;
    )
    ~on_error:(fun err ->
      Printf.eprintf "Auth failed: %s\n" err
    )
```

## Configuration Options

### Default Scopes

By default, the provider requests:
- `read:user` - Read user profile information
- `user:email` - Access user email addresses

### Custom Scopes

```ocaml
let config = Auth_provider_github_v2.make_config
  ~client_id:"..."
  ~client_secret:"..."
  ~redirect_uri:"..."
  ~scopes:[
    "read:user";
    "user:email";
    (* Add additional scopes *)
    "repo";  (* Access repositories *)
    "read:org";  (* Read org membership *)
  ]
  ()
```

### Available Scopes

Common GitHub OAuth scopes:
- `user` - Read/write all user profile data
- `read:user` - Read user profile (recommended for auth)
- `user:email` - Access email addresses
- `repo` - Full repository access
- `public_repo` - Public repository access only
- `read:org` - Read organization membership

See [GitHub OAuth Scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps) for complete list.

## User Info Fields

The `parse_user_info` function extracts:

| Field | Type | Description |
|-------|------|-------------|
| `provider` | `provider` | Always `GitHub` |
| `provider_user_id` | `string` | GitHub user ID (numeric, converted to string) |
| `email` | `string option` | Primary email (null if not public) |
| `email_verified` | `bool option` | Always `None` (not in user endpoint) |
| `name` | `string option` | Full name |
| `given_name` | `string option` | Always `None` (GitHub doesn't separate) |
| `family_name` | `string option` | Always `None` |
| `username` | `string option` | GitHub username/login |
| `avatar_url` | `string option` | Profile picture URL |
| `locale` | `string option` | Always `None` (not provided) |
| `raw_response` | `Yojson.Basic.t` | Full JSON for custom fields |

## Email Verification

GitHub's `/user` endpoint doesn't include email verification status. To get verified emails, make a separate request to `/user/emails`:

```ocaml
(* After authentication *)
let get_verified_emails ~access_token =
  (* Make GET request to https://api.github.com/user/emails *)
  (* Returns array of email objects with "verified" field *)
```

Example response from `/user/emails`:
```json
[
  {
    "email": "user@example.com",
    "verified": true,
    "primary": true,
    "visibility": "public"
  }
]
```

## Complete Example with Lwt

```ocaml
open Lwt.Syntax

(* Define HTTP client - see auth-provider-lwt for complete implementation *)
module GitHub_auth = Auth_provider_lwt

let authenticate () =
  let config = Auth_provider_github_v2.make_config
    ~client_id:(Sys.getenv "GITHUB_CLIENT_ID")
    ~client_secret:(Sys.getenv "GITHUB_CLIENT_SECRET")
    ~redirect_uri:"http://localhost:8080/auth/github/callback"
    ()
  in
  
  let (oauth_state, auth_url) = 
    GitHub_auth.start_authorization_flow config 
  in
  
  Printf.printf "Visit: %s\n" auth_url;
  Printf.printf "Enter authorization code: ";
  flush stdout;
  
  let code = read_line () in
  
  let* result = GitHub_auth.complete_oauth_flow
    config
    ~code
    ~code_verifier:oauth_state.code_verifier
    ~parse_user_info:Auth_provider_github_v2.parse_user_info
  in
  
  match result with
  | Ok (token, user_info) ->
      Printf.printf "✓ Authenticated!\n";
      Printf.printf "  Username: %s\n" 
        (Option.value user_info.username ~default:"no username");
      Printf.printf "  GitHub ID: %s\n" user_info.provider_user_id;
      Printf.printf "  Email: %s\n" 
        (Option.value user_info.email ~default:"not public");
      Printf.printf "  Access Token: %s...\n" 
        (String.sub token.access_token 0 10);
      Lwt.return_unit
  | Error err ->
      Printf.eprintf "✗ Auth failed: %s\n" err;
      Lwt.return_unit
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
  Auth_provider_core.provider_config
```

Create GitHub OAuth2 configuration.

### `parse_user_info`

```ocaml
val parse_user_info : 
  string -> 
  (Auth_provider_core.user_info, string) result
```

Parse GitHub user info JSON response.

### `validate_scopes`

```ocaml
val validate_scopes : string list -> (unit, string) result
```

Validate that required scopes are present.

## GitHub API Notes

### Rate Limiting

- **Unauthenticated**: 60 requests/hour
- **Authenticated**: 5,000 requests/hour
- OAuth tokens count as authenticated

### User Privacy

- Email may be `null` if user hasn't made it public
- Use `/user/emails` endpoint to get all emails (requires `user:email` scope)
- Username is always available

### Token Expiration

- GitHub OAuth tokens **do not expire** by default
- Tokens can be revoked by user at any time
- No refresh token needed

## GitHub OAuth Documentation

- [OAuth Apps](https://docs.github.com/en/apps/oauth-apps)
- [Authorizing OAuth Apps](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps)
- [OAuth Scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps)
- [GitHub API](https://docs.github.com/en/rest)

## License

MIT
