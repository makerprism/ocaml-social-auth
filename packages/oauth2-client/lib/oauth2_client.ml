(** OAuth2 Client - Runtime-agnostic OAuth2 client library *)

(** {1 Core Modules} *)

(** Authentication types and configurations *)
module Auth_types = Auth_types

(** PKCE (Proof Key for Code Exchange) utilities - functor version *)
module Pkce = Pkce

(** OAuth2 flow implementation *)
module Oauth2_flow = Oauth2_flow

(** ID Token (JWT) validation for OpenID Connect *)
module Id_token = Id_token

(** {1 Module Types} *)

(** Random number generator interface.
    
    Implementations must provide cryptographically secure random bytes.
    This is used for PKCE code verifiers and CSRF state tokens.
    
    Example implementation using mirage-crypto-rng:
    {[
      module Rng : Oauth2_client.RNG = struct
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
      module My_rng : Oauth2_client.RNG = struct
        let generate n = (* ... cryptographically secure bytes ... *)
      end
      
      module My_pkce = Oauth2_client.Make_pkce(My_rng)
      
      let verifier = My_pkce.generate_code_verifier ()
      let challenge = My_pkce.generate_code_challenge verifier
    ]}
*)
module Make_pkce = Pkce.Make

(** Create OAuth2 flow implementation with given HTTP client and PKCE module.
    
    Example:
    {[
      module My_rng : Oauth2_client.RNG = struct
        let generate n = (* ... *)
      end
      
      module My_pkce = Oauth2_client.Make_pkce(My_rng)
      
      module My_http : Oauth2_client.HTTP_CLIENT = struct
        let post ~url ~headers ~body ~on_success ~on_error = (* ... *)
        let get ~url ~headers ~on_success ~on_error = (* ... *)
      end
      
      module Oauth2 = Oauth2_client.Make_oauth2_flow(My_http)(My_pkce)
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

(** {1 ID Token Validation} *)

(** ID token claims from OpenID Connect *)
type id_token_claims = Id_token.id_token_claims = {
  iss : string;
  sub : string;
  aud : string list;
  exp : int;
  iat : int;
  nonce : string option;
  auth_time : int option;
  azp : string option;
  at_hash : string option;
  email : string option;
  email_verified : bool option;
  name : string option;
  picture : string option;
  given_name : string option;
  family_name : string option;
  locale : string option;
}

(** ID token validation configuration *)
type id_token_validation_config = Id_token.validation_config = {
  issuer : string;
  client_id : string;
  clock_skew_seconds : int;
  require_nonce : bool;
  expected_nonce : string option;
}

(** ID token validation errors *)
type id_token_validation_error = Id_token.validation_error =
  | Invalid_format of string
  | Invalid_base64 of string
  | Invalid_json of string
  | Missing_claim of string
  | Invalid_issuer of { expected : string; actual : string }
  | Invalid_audience of { expected : string; actual : string list }
  | Token_expired of { exp : int; now : int }
  | Token_not_yet_valid of { iat : int; now : int }
  | Invalid_nonce of { expected : string; actual : string option }
  | Missing_nonce
  | Signature_verification_not_implemented
  | Algorithm_not_supported of string

(** Indicates how an ID token was obtained.
    
    For tokens received directly from the provider's token endpoint over HTTPS,
    signature verification is redundant - TLS already authenticates the source.
    
    For tokens from untrusted sources (browser, mobile app), you need signature
    verification using an external JWT library with JWKS support.
*)
type id_token_source = Id_token.token_source =
  | Direct_from_token_endpoint
  | From_untrusted_source

(** Validate an ID token and extract claims.
    
    For the standard server-side OAuth2 flow where tokens are received
    directly from the provider's token endpoint over HTTPS, this provides
    complete validation. TLS authenticates the token source, making
    signature verification redundant.
    
    See {!Id_token} module documentation for the full security model.
*)
let validate_id_token = Id_token.validate_id_token

(** Validate an ID token with explicit source indication.
    
    Use this when you want to be explicit about the security model.
    Tokens from untrusted sources will be rejected with an error
    message directing you to use an external JWT library.
*)
let validate_id_token_from_source = Id_token.validate_id_token_from_source

(** Create validation config for Google OIDC *)
let google_id_token_config = Id_token.google_validation_config

(** Create validation config for Microsoft OIDC *)
let microsoft_id_token_config = Id_token.microsoft_validation_config

(** Convert validation error to string *)
let id_token_error_to_string = Id_token.validation_error_to_string

(** Extract user info from validated ID token claims *)
let user_info_from_id_token = Id_token.user_info_from_claims
