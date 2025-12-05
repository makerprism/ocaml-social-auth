(** Social Auth Core - Runtime-agnostic OAuth2 authentication library *)

(** {1 Core Modules} *)

(** Authentication types and configurations *)
module Auth_types = Auth_types

(** PKCE (Proof Key for Code Exchange) utilities - functor version *)
module Pkce = Pkce

(** OAuth2 flow implementation *)
module Oauth2_flow = Oauth2_flow

(** {1 Module Types} *)

(** Random number generator interface.
    
    Implementations must provide cryptographically secure random bytes.
    This is used for PKCE code verifiers and CSRF state tokens.
    
    Example implementation using mirage-crypto-rng:
    {[
      module Rng : Social_auth_core.RNG = struct
        let generate n =
          let cs = Mirage_crypto_rng.generate n in
          let buf = Bytes.create n in
          for i = 0 to n - 1 do
            Bytes.set_uint8 buf i (Cstruct.get_uint8 cs i)
          done;
          buf
      end
    ]}
*)
module type RNG = Auth_types.RNG

(** HTTP client interface for runtime-agnostic implementation *)
module type HTTP_CLIENT = Oauth2_flow.HTTP_CLIENT

(** PKCE module signature *)
module type PKCE = Pkce.S

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

(** {1 Functors} *)

(** Create a PKCE module with the given RNG implementation.
    
    Example:
    {[
      module My_rng : Social_auth_core.RNG = struct
        let generate n = (* ... cryptographically secure bytes ... *)
      end
      
      module My_pkce = Social_auth_core.Make_pkce(My_rng)
      
      let verifier = My_pkce.generate_code_verifier ()
      let challenge = My_pkce.generate_code_challenge verifier
    ]}
*)
module Make_pkce = Pkce.Make

(** Create OAuth2 flow implementation with given HTTP client and PKCE module.
    
    Example:
    {[
      module My_rng : Social_auth_core.RNG = struct
        let generate n = (* ... *)
      end
      
      module My_pkce = Social_auth_core.Make_pkce(My_rng)
      
      module My_http : Social_auth_core.HTTP_CLIENT = struct
        let post ~url ~headers ~body ~on_success ~on_error = (* ... *)
        let get ~url ~headers ~on_success ~on_error = (* ... *)
      end
      
      module Oauth2 = Social_auth_core.Make_oauth2_flow(My_http)(My_pkce)
    ]}
*)
module Make_oauth2_flow = Oauth2_flow.Make

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

(** Build authorization URL *)
let build_authorization_url = Oauth2_flow.build_authorization_url
