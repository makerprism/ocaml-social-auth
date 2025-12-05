(** Authentication Provider Types - Core types for OAuth2 authentication *)

(** {1 Provider Types} *)

(** OAuth2 provider identifier *)
type provider = 
  | Google
  | GitHub
  | Microsoft
  | Custom of string

let provider_to_string = function
  | Google -> "google"
  | GitHub -> "github"
  | Microsoft -> "microsoft"
  | Custom s -> s

let provider_of_string = function
  | "google" -> Some Google
  | "github" -> Some GitHub
  | "microsoft" -> Some Microsoft
  | s -> Some (Custom s)

(** {1 OAuth2 Token Types} *)

(** OAuth2 token response from provider *)
type token_response = {
  access_token : string;
  token_type : string;
  expires_in : int option;
  refresh_token : string option;
  scope : string option;
  id_token : string option; (* For OpenID Connect providers *)
}

(** {1 User Information Types} *)

(** User information returned by provider *)
type user_info = {
  provider : provider;
  provider_user_id : string;
  email : string option;
  email_verified : bool option;
  name : string option;
  given_name : string option;
  family_name : string option;
  username : string option;
  avatar_url : string option;
  locale : string option;
  raw_response : Yojson.Basic.t; (* Raw JSON for provider-specific fields *)
}

(** {1 OAuth2 State Types} *)

(** OAuth2 state for CSRF protection and PKCE *)
type oauth_state = {
  state : string;              (* CSRF token *)
  code_verifier : string;      (* PKCE code verifier *)
  provider : provider;
  redirect_uri : string;       (* Store redirect URI with state *)
  created_at : float;          (* Unix timestamp *)
  expires_at : float;          (* Unix timestamp *)
  custom_data : string option; (* Optional app-specific data (JSON string) *)
}

(** {1 Provider Configuration Types} *)

(** OAuth2 provider configuration *)
type provider_config = {
  provider : provider;            (* Provider identifier *)
  client_id : string;
  client_secret : string option;  (* Optional - not needed for pure PKCE *)
  redirect_uri : string;
  scopes : string list;
  auth_endpoint : string;
  token_endpoint : string;
  user_info_endpoint : string;
  extra_auth_params : (string * string) list; (* Provider-specific params *)
}

(** {1 HTTP Response Types} *)

(** HTTP response abstraction *)
type http_response = {
  status : int;
  headers : (string * string) list;
  body : string;
}

(** {1 Error Types} *)

(** OAuth2 error from provider *)
type oauth_error = {
  error : string;
  error_description : string option;
  error_uri : string option;
}

(** Authentication result *)
type ('ok, 'err) result = 
  | Ok of 'ok
  | Error of 'err

(** {1 Utility Functions} *)

(** Parse OAuth error from query parameters *)
let parse_oauth_error ~error ~error_description ~error_uri =
  {
    error;
    error_description;
    error_uri;
  }

(** Convert OAuth error to string *)
let oauth_error_to_string err =
  match err.error_description with
  | Some desc -> Printf.sprintf "%s: %s" err.error desc
  | None -> err.error

(** Parse token response from JSON *)
let parse_token_response json =
  try
    let open Yojson.Basic.Util in
    let access_token = json |> member "access_token" |> to_string in
    let token_type = try json |> member "token_type" |> to_string with _ -> "Bearer" in
    let expires_in = try Some (json |> member "expires_in" |> to_int) with _ -> None in
    let refresh_token = try Some (json |> member "refresh_token" |> to_string) with _ -> None in
    let scope = try Some (json |> member "scope" |> to_string) with _ -> None in
    let id_token = try Some (json |> member "id_token" |> to_string) with _ -> None in
    Ok { access_token; token_type; expires_in; refresh_token; scope; id_token }
  with e ->
    Error (Printf.sprintf "Failed to parse token response: %s" (Printexc.to_string e))

(** Create JSON from token response *)
let token_response_to_json token =
  `Assoc [
    ("access_token", `String token.access_token);
    ("token_type", `String token.token_type);
    ("expires_in", match token.expires_in with Some i -> `Int i | None -> `Null);
    ("refresh_token", match token.refresh_token with Some s -> `String s | None -> `Null);
    ("scope", match token.scope with Some s -> `String s | None -> `Null);
    ("id_token", match token.id_token with Some s -> `String s | None -> `Null);
  ]
