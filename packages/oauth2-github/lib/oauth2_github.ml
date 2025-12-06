(** GitHub OAuth2 Provider *)

open Oauth2_client

(** {1 GitHub OAuth 2.0 Configuration} *)

(** GitHub OAuth 2.0 endpoints *)
let auth_endpoint = "https://github.com/login/oauth/authorize"
let token_endpoint = "https://github.com/login/oauth/access_token"
let user_info_endpoint = "https://api.github.com/user"

(** GitHub OAuth 2.0 default scopes for authentication *)
let default_scopes = [
  "read:user";
  "user:email";
]

(** {1 Provider Configuration} *)

(** Create GitHub OAuth2 provider configuration
    
    @param client_id GitHub OAuth App client ID
    @param client_secret GitHub OAuth App client secret
    @param redirect_uri OAuth2 redirect URI (must match GitHub App settings)
    @param scopes Optional custom scopes (defaults to read:user + user:email)
    @return Provider configuration for use with oauth2-client
*)
let make_config 
    ~client_id 
    ~client_secret 
    ~redirect_uri 
    ?(scopes=default_scopes) 
    () =
  {
    provider = GitHub;
    client_id;
    client_secret = Some client_secret;  (* GitHub requires client secret *)
    redirect_uri;
    scopes;
    auth_endpoint;
    token_endpoint;
    user_info_endpoint;
    extra_auth_params = [];
  }

(** {1 User Info Parsing} *)

(** Parse GitHub user info from JSON response
    
    @param json_body Raw JSON response body from GitHub user API endpoint
    @return Parsed user info or error message
    
    GitHub user response fields:
    - id: GitHub user ID (required)
    - login: Username (required)
    - email: Primary email (may be null if not public)
    - name: Full name
    - avatar_url: Avatar URL
    - bio: User bio
    - blog: Website URL
*)
let parse_user_info json_body =
  try
    let open Yojson.Basic.Util in
    let json = Yojson.Basic.from_string json_body in
    
    (* GitHub uses numeric ID, convert to string *)
    let provider_user_id = 
      try json |> member "id" |> to_int |> string_of_int
      with _ -> json |> member "id" |> to_string
    in
    
    let user_info = {
      provider = GitHub;
      provider_user_id;
      email = (try Some (json |> member "email" |> to_string) with _ -> None);
      email_verified = None;  (* GitHub doesn't provide email_verified in user endpoint *)
      name = (try Some (json |> member "name" |> to_string) with _ -> None);
      given_name = None;  (* GitHub doesn't separate first/last name *)
      family_name = None;
      username = (try Some (json |> member "login" |> to_string) with _ -> None);
      avatar_url = (try Some (json |> member "avatar_url" |> to_string) with _ -> None);
      locale = None;  (* GitHub doesn't provide locale *)
      raw_response = json;
    } in
    Ok user_info
  with e ->
    Error (Printf.sprintf "Failed to parse GitHub user info: %s" (Printexc.to_string e))

(** {1 Provider Interface Implementation} *)

(** Provider identifier *)
let provider = GitHub

(** {1 Convenience Functions} *)

(** Create a minimal configuration for testing/development *)
let make_test_config ~client_id ~client_secret ~redirect_uri () =
  make_config ~client_id ~client_secret ~redirect_uri ()

(** Check if a scope list includes user email scope *)
let has_email_scope scopes =
  List.exists (fun s -> s = "user:email" || s = "user") scopes

(** Check if a scope list includes read user scope *)
let has_read_user_scope scopes =
  List.exists (fun s -> s = "read:user" || s = "user") scopes

(** Validate that required scopes are present *)
let validate_scopes scopes =
  if not (has_read_user_scope scopes) then
    Error "GitHub authentication requires 'read:user' or 'user' scope"
  else
    Ok ()

(** {1 Additional Endpoints} *)

(** GitHub user emails endpoint for fetching all email addresses
    
    Note: This requires a separate API call and the user:email scope.
    Use this to get email verification status and all emails.
*)
let user_emails_endpoint = "https://api.github.com/user/emails"
