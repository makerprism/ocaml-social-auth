# auth-provider-microsoft-v2

Microsoft/Azure AD OAuth2 authentication provider for `auth-provider-core`.

## Overview

Supports both:
- ✅ Personal Microsoft Accounts (Outlook, Xbox, etc.)
- ✅ Azure AD Work/School Accounts
- ✅ OpenID Connect with ID tokens
- ✅ Microsoft Graph API integration

## Installation

```bash
opam install auth-provider-microsoft-v2
```

## Quick Start

### 1. Register App in Azure Portal

1. Go to [Azure Portal](https://portal.azure.com/)
2. Navigate to "Azure Active Directory" → "App registrations"
3. Click "New registration"
4. Set redirect URI (e.g., `https://yourapp.com/auth/microsoft/callback`)
5. Under "Certificates & secrets", create a client secret
6. Copy Application (client) ID and client secret

### 2. Use with auth-provider-core

```ocaml
(* Create Microsoft config *)
let microsoft_config = Auth_provider_microsoft_v2.make_config
  ~client_id:"your-application-id"
  ~client_secret:"your-client-secret"
  ~redirect_uri:"https://yourapp.com/auth/microsoft/callback"
  ()

(* Use with auth-provider-lwt *)
let (oauth_state, auth_url) = 
  Auth_provider_lwt.start_authorization_flow microsoft_config

(* Handle callback *)
let* result = Auth_provider_lwt.complete_oauth_flow
  microsoft_config
  ~code
  ~code_verifier:oauth_state.code_verifier
  ~parse_user_info:Auth_provider_microsoft_v2.parse_user_info
```

## Configuration Options

### Default (Multi-tenant)

Allows both personal and work accounts:

```ocaml
let config = Auth_provider_microsoft_v2.make_config
  ~client_id:"..."
  ~client_secret:"..."
  ~redirect_uri:"..."
  ()
```

### Work/School Accounts Only

```ocaml
let config = Auth_provider_microsoft_v2.make_organizations_config
  ~client_id:"..."
  ~client_secret:"..."
  ~redirect_uri:"..."
  ()
```

### Personal Accounts Only

```ocaml
let config = Auth_provider_microsoft_v2.make_consumers_config
  ~client_id:"..."
  ~client_secret:"..."
  ~redirect_uri:"..."
  ()
```

### Specific Tenant

```ocaml
let config = Auth_provider_microsoft_v2.make_tenant_config
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
