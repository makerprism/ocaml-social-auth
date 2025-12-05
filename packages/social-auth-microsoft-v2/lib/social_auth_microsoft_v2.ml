(** Microsoft/Azure AD OAuth2 Authentication Provider *)

open Social_auth_core

(** {1 Microsoft Identity Platform Configuration} *)

(** Microsoft OAuth 2.0 endpoints (common tenant for consumer + work accounts) *)
let auth_endpoint = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
let token_endpoint = "https://login.microsoftonline.com/common/oauth2/v2.0/token"
let user_info_endpoint = "https://graph.microsoft.com/v1.0/me"

(** Microsoft OAuth 2.0 default scopes for authentication *)
let default_scopes = [
  "openid";
  "profile";
  "email";
  "User.Read";  (* Microsoft Graph API - read user profile *)
]

(** {1 Provider Configuration} *)

(** Create Microsoft OAuth2 provider configuration
    
    @param client_id Microsoft App registration client ID (Application ID)
    @param client_secret Microsoft App registration client secret
    @param redirect_uri OAuth2 redirect URI (must match App registration)
    @param scopes Optional custom scopes (defaults to openid + profile + email + User.Read)
    @param tenant Optional tenant ID (defaults to "common" for multi-tenant)
    @return Provider configuration for use with social-auth-core
    
    Tenant options:
    - "common" - Personal Microsoft accounts + Work/School accounts (default)
    - "organizations" - Work/School accounts only
    - "consumers" - Personal Microsoft accounts only
    - "{tenant-id}" - Specific Azure AD tenant
*)
let make_config 
    ~client_id 
    ~client_secret 
    ~redirect_uri 
    ?(scopes=default_scopes)
    ?(tenant="common")
    () =
  {
    provider = Microsoft;
    client_id;
    client_secret = Some client_secret;  (* Microsoft requires client secret *)
    redirect_uri;
    scopes;
    auth_endpoint = Printf.sprintf "https://login.microsoftonline.com/%s/oauth2/v2.0/authorize" tenant;
    token_endpoint = Printf.sprintf "https://login.microsoftonline.com/%s/oauth2/v2.0/token" tenant;
    user_info_endpoint;
    extra_auth_params = [
      ("response_mode", "query");
    ];
  }

(** {1 User Info Parsing} *)

(** Parse Microsoft user info from Microsoft Graph API response
    
    @param json_body Raw JSON response body from Microsoft Graph /me endpoint
    @return Parsed user info or error message
    
    Microsoft Graph /me response fields:
    - id: Microsoft user ID (required)
    - userPrincipalName: Email/UPN (required)
    - mail: Email address (may be null for personal accounts)
    - displayName: Full name
    - givenName: First name
    - surname: Last name
    - jobTitle: Job title
    - officeLocation: Office location
*)
let parse_user_info json_body =
  try
    let open Yojson.Basic.Util in
    let json = Yojson.Basic.from_string json_body in
    
    let provider_user_id = json |> member "id" |> to_string in
    
    (* Microsoft uses "mail" for email, but it can be null for personal accounts *)
    (* Fall back to userPrincipalName which is always present *)
    let email = 
      try Some (json |> member "mail" |> to_string)
      with _ -> 
        try Some (json |> member "userPrincipalName" |> to_string)
        with _ -> None
    in
    
    let user_info = {
      provider = Microsoft;
      provider_user_id;
      email;
      email_verified = None;  (* Microsoft doesn't provide this in /me endpoint *)
      name = (try Some (json |> member "displayName" |> to_string) with _ -> None);
      given_name = (try Some (json |> member "givenName" |> to_string) with _ -> None);
      family_name = (try Some (json |> member "surname" |> to_string) with _ -> None);
      username = (try Some (json |> member "userPrincipalName" |> to_string) with _ -> None);
      avatar_url = None;  (* Microsoft doesn't include avatar in /me, need separate call to /me/photo *)
      locale = (try Some (json |> member "preferredLanguage" |> to_string) with _ -> None);
      raw_response = json;
    } in
    Ok user_info
  with e ->
    Error (Printf.sprintf "Failed to parse Microsoft user info: %s" (Printexc.to_string e))

(** {1 Provider Interface Implementation} *)

(** Provider identifier *)
let provider = Microsoft

(** {1 Convenience Functions} *)

(** Create configuration for organizations (work/school accounts) only *)
let make_organizations_config ~client_id ~client_secret ~redirect_uri ?scopes () =
  make_config ~client_id ~client_secret ~redirect_uri ?scopes ~tenant:"organizations" ()

(** Create configuration for consumers (personal accounts) only *)
let make_consumers_config ~client_id ~client_secret ~redirect_uri ?scopes () =
  make_config ~client_id ~client_secret ~redirect_uri ?scopes ~tenant:"consumers" ()

(** Create configuration for specific tenant *)
let make_tenant_config ~client_id ~client_secret ~redirect_uri ~tenant ?scopes () =
  make_config ~client_id ~client_secret ~redirect_uri ?scopes ~tenant ()

(** Check if scope list includes User.Read scope *)
let has_user_read_scope scopes =
  List.exists (fun s -> 
    String.lowercase_ascii s = "user.read"
  ) scopes

(** Validate that required scopes are present *)
let validate_scopes scopes =
  if not (List.mem "openid" scopes) then
    Error "Microsoft authentication requires 'openid' scope"
  else if not (has_user_read_scope scopes) then
    Error "Microsoft authentication requires 'User.Read' scope for profile access"
  else
    Ok ()

(** {1 Additional Endpoints} *)

(** Microsoft Graph photo endpoint for getting user avatar
    
    Note: This requires a separate API call.
    GET https://graph.microsoft.com/v1.0/me/photo/$value
*)
let photo_endpoint = "https://graph.microsoft.com/v1.0/me/photo/$value"
