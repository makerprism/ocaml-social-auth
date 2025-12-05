# social-auth-microsoft-v2

Microsoft/Azure AD OAuth2 authentication provider for `social-auth-core`.

> **Warning**
> This library is **not production-ready**. It was primarily built using LLMs and is still a work in progress. We are actively working towards making it stable and usable.
>
> **Current status:** This provider has not been tested yet and should be considered experimental.

## Overview

Supports both:
- ✅ Personal Microsoft Accounts (Outlook, Xbox, etc.)
- ✅ Azure AD Work/School Accounts
- ✅ OpenID Connect with ID tokens
- ✅ Microsoft Graph API integration

## Installation

```bash
opam install social-auth-microsoft-v2
```

## Quick Start

### 1. Register App in Azure Portal

1. Go to [Azure Portal](https://portal.azure.com/)
2. Navigate to "Azure Active Directory" → "App registrations"
3. Click "New registration"
4. Set redirect URI (e.g., `https://yourapp.com/auth/microsoft/callback`)
5. Under "Certificates & secrets", create a client secret
6. Copy Application (client) ID and client secret

### 2. Use with social-auth-core

```ocaml
(* Create Microsoft config *)
let microsoft_config = Social_auth_microsoft_v2.make_config
  ~client_id:"your-application-id"
  ~client_secret:"your-client-secret"
  ~redirect_uri:"https://yourapp.com/auth/microsoft/callback"
  ()

(* Use with social-auth-lwt *)
let (oauth_state, auth_url) = 
  Social_auth_lwt.start_authorization_flow microsoft_config

(* Handle callback *)
let* result = Social_auth_lwt.complete_oauth_flow
  microsoft_config
  ~code
  ~code_verifier:oauth_state.code_verifier
  ~parse_user_info:Social_auth_microsoft_v2.parse_user_info
```

## Configuration Options

### Default (Multi-tenant)

Allows both personal and work accounts:

```ocaml
let config = Social_auth_microsoft_v2.make_config
  ~client_id:"..."
  ~client_secret:"..."
  ~redirect_uri:"..."
  ()
```

### Work/School Accounts Only

```ocaml
let config = Social_auth_microsoft_v2.make_organizations_config
  ~client_id:"..."
  ~client_secret:"..."
  ~redirect_uri:"..."
  ()
```

### Personal Accounts Only

```ocaml
let config = Social_auth_microsoft_v2.make_consumers_config
  ~client_id:"..."
  ~client_secret:"..."
  ~redirect_uri:"..."
  ()
```

### Specific Tenant

```ocaml
let config = Social_auth_microsoft_v2.make_tenant_config
  ~client_id:"..."
  ~client_secret:"..."
  ~redirect_uri:"..."
  ~tenant:"your-tenant-id"
  ()
```

## Scopes

Default scopes:
- `openid` - OpenID Connect
- `profile` - User profile
- `email` - Email address
- `User.Read` - Microsoft Graph API access

Custom scopes:
```ocaml
~scopes:[
  "openid"; "profile"; "email"; "User.Read";
  "Mail.Read";  (* Read mail *)
  "Calendars.Read";  (* Read calendar *)
]
```

## User Info

| Field | Source |
|-------|--------|
| `email` | `mail` or `userPrincipalName` |
| `name` | `displayName` |
| `given_name` | `givenName` |
| `family_name` | `surname` |
| `username` | `userPrincipalName` |
| `locale` | `preferredLanguage` |
| `avatar_url` | Not included (need `/me/photo` call) |

## Microsoft OAuth Documentation

- [Microsoft Identity Platform](https://docs.microsoft.com/en-us/azure/active-directory/develop/)
- [OAuth 2.0 Flow](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow)
- [Microsoft Graph API](https://docs.microsoft.com/en-us/graph/)

## License

MIT
