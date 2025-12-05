(** Auth Provider Core - Runtime-agnostic OAuth2 authentication library *)

(** {1 Core Modules} *)

(** Authentication types and configurations *)
module Auth_types = Auth_types

(** PKCE (Proof Key for Code Exchange) utilities *)
module Pkce = Pkce

(** OAuth2 flow implementation *)
module Oauth2_flow = Oauth2_flow

(** {1 Re-exports for Convenience} *)

(** Provider types *)
type provider = Auth_types.provider =
  | Google
  | GitHub
  | Microsoft
  | Custom of string

(** Token response from OAuth2 provider *)
type token_response = Auth_types.token_response = {
  access_token : string;
  token_type : string;
  expires_in : int option;
  refresh_token : string option;
  scope : string option;
  id_token : string option;
}

(** User information from provider *)
type user_info = Auth_types.user_info = {
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
  raw_response : Yojson.Basic.t;
}

(** OAuth2 state for CSRF protection *)
type oauth_state = Auth_types.oauth_state = {
  state : string;
  code_verifier : string;
  provider : provider;
  redirect_uri : string;
  created_at : float;
  expires_at : float;
  custom_data : string option;
}

(** Provider configuration *)
type provider_config = Auth_types.provider_config = {
  provider : provider;
  client_id : string;
  client_secret : string option;
  redirect_uri : string;
  scopes : string list;
  auth_endpoint : string;
  token_endpoint : string;
  user_info_endpoint : string;
  extra_auth_params : (string * string) list;
}

(** HTTP response *)
type http_response = Auth_types.http_response = {
  status : int;
  headers : (string * string) list;
  body : string;
}

(** OAuth2 error *)
type oauth_error = Auth_types.oauth_error = {
  error : string;
  error_description : string option;
  error_uri : string option;
}

(** Result type *)
type ('ok, 'err) result = ('ok, 'err) Auth_types.result =
  | Ok of 'ok
  | Error of 'err

(** {1 HTTP Client Interface} *)

(** HTTP client interface for runtime-agnostic implementation *)
module type HTTP_CLIENT = Oauth2_flow.HTTP_CLIENT

(** {1 Provider Interface} *)

(** Provider-specific implementation interface *)
module type PROVIDER = sig
  (** Provider identifier *)
  val provider : provider
  
  (** Create provider configuration
      @param client_id OAuth2 client ID
      @param client_secret Optional client secret (not needed for pure PKCE)
      @param redirect_uri OAuth2 redirect URI
      @return Provider configuration
  *)
  val make_config : 
    client_id:string ->
    ?client_secret:string ->
    redirect_uri:string ->
    unit ->
    provider_config
  
  (** Parse user info from JSON response
      @param json_body Raw JSON response body
      @return Parsed user info or error message
  *)
  val parse_user_info : string -> (user_info, string) result
end

(** {1 Utility Functions} *)

(** Convert provider to string *)
let provider_to_string = Auth_types.provider_to_string

(** Parse provider from string *)
let provider_of_string = Auth_types.provider_of_string

(** Convert OAuth error to string *)
let oauth_error_to_string = Auth_types.oauth_error_to_string

(** Parse token response from JSON *)
let parse_token_response = Auth_types.parse_token_response

(** Convert token response to JSON *)
let token_response_to_json = Auth_types.token_response_to_json

(** Generate PKCE code verifier *)
let generate_code_verifier = Pkce.generate_code_verifier

(** Generate PKCE code challenge *)
let generate_code_challenge = Pkce.generate_code_challenge

(** Generate CSRF state token *)
let generate_state = Pkce.generate_state

(** Build authorization URL *)
let build_authorization_url = Oauth2_flow.build_authorization_url

(** {1 OAuth2 Flow} *)

(** Create OAuth2 flow implementation with given HTTP client *)
module Make_oauth2_flow = Oauth2_flow.Make
