(** Google OAuth2 Authentication Provider *)

open Auth_provider_core

(** {1 Google OAuth 2.0 Configuration} *)

(** Google OAuth 2.0 endpoints *)
let auth_endpoint = "https://accounts.google.com/o/oauth2/v2/auth"
let token_endpoint = "https://oauth2.googleapis.com/token"
let user_info_endpoint = "https://www.googleapis.com/oauth2/v2/userinfo"

(** Google OAuth 2.0 default scopes for authentication *)
let default_scopes = [
  "openid";
  "https://www.googleapis.com/auth/userinfo.email";
  "https://www.googleapis.com/auth/userinfo.profile"
]

(** {1 Provider Configuration} *)

(** Create Google OAuth2 provider configuration
    
    @param client_id Google OAuth 2.0 client ID
    @param client_secret Google OAuth 2.0 client secret
    @param redirect_uri OAuth2 redirect URI (must match Google Console config)
    @param scopes Optional custom scopes (defaults to openid + email + profile)
    @return Provider configuration for use with auth-provider-core
*)
let make_config 
    ~client_id 
    ~client_secret 
    ~redirect_uri 
    ?(scopes=default_scopes) 
    () =
  {
    provider = Google;
    client_id;
    client_secret = Some client_secret;  (* Google requires client secret *)
    redirect_uri;
    scopes;
    auth_endpoint;
    token_endpoint;
    user_info_endpoint;
    extra_auth_params = [
      (* Request access_type=offline to get refresh token *)
      (* Add this if you need refresh tokens: ("access_type", "offline"); *)
      (* Add this to force consent screen: ("prompt", "consent"); *)
    ];
  }

(** {1 User Info Parsing} *)

(** Parse Google user info from JSON response
    
    @param json_body Raw JSON response body from Google userinfo endpoint
    @return Parsed user info or error message
    
    Google userinfo response fields:
    - id: Google user ID (required)
    - email: User's email address (may be absent if not granted)
    - verified_email: Whether email is verified
    - name: Full name
    - given_name: First name
    - family_name: Last name
    - picture: Avatar URL
    - locale: User's locale (e.g., "en")
*)
let parse_user_info json_body =
  try
    let open Yojson.Basic.Util in
    let json = Yojson.Basic.from_string json_body in
    
    (* Google uses "sub" (subject) in OpenID Connect, but "id" in userinfo v2 *)
    let provider_user_id = 
      try json |> member "id" |> to_string
      with _ -> json |> member "sub" |> to_string
    in
    
    let user_info = {
      provider = Google;
      provider_user_id;
      email = (try Some (json |> member "email" |> to_string) with _ -> None);
      email_verified = (try Some (json |> member "verified_email" |> to_bool) with _ -> None);
      name = (try Some (json |> member "name" |> to_string) with _ -> None);
      given_name = (try Some (json |> member "given_name" |> to_string) with _ -> None);
      family_name = (try Some (json |> member "family_name" |> to_string) with _ -> None);
      username = None;  (* Google doesn't provide username *)
      avatar_url = (try Some (json |> member "picture" |> to_string) with _ -> None);
      locale = (try Some (json |> member "locale" |> to_string) with _ -> None);
      raw_response = json;
    } in
    Ok user_info
  with e ->
    Error (Printf.sprintf "Failed to parse Google user info: %s" (Printexc.to_string e))

(** {1 Provider Interface Implementation} *)

(** Provider identifier *)
let provider = Google

(** {1 Convenience Functions} *)

(** Create a minimal configuration for testing/development
    
    Note: For production, use make_config with proper credentials
*)
let make_test_config ~client_id ~client_secret ~redirect_uri () =
  make_config ~client_id ~client_secret ~redirect_uri ()

(** Check if a scope list includes email scope *)
let has_email_scope scopes =
  List.exists (fun s -> 
    s = "https://www.googleapis.com/auth/userinfo.email" ||
    s = "email"
  ) scopes

(** Check if a scope list includes profile scope *)
let has_profile_scope scopes =
  List.exists (fun s -> 
    s = "https://www.googleapis.com/auth/userinfo.profile" ||
    s = "profile"
  ) scopes

(** Validate that required scopes are present *)
let validate_scopes scopes =
  if not (List.mem "openid" scopes) then
    Error "Google authentication requires 'openid' scope"
  else if not (has_email_scope scopes || has_profile_scope scopes) then
    Error "Google authentication requires at least 'email' or 'profile' scope"
  else
    Ok ()
