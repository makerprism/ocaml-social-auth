(** ID Token (JWT) Validation for OpenID Connect 

    {1 Security Model}
    
    This module validates ID token {i claims} but does NOT verify JWT signatures.
    This is intentional and secure for the standard OAuth2/OIDC server-side flow:
    
    {2 When signature verification is NOT needed}
    
    If your application:
    - Receives the ID token directly from the provider's token endpoint
    - Uses HTTPS with proper TLS certificate validation
    - Runs the token exchange on your backend server
    
    Then signature verification is {b redundant}. The TLS connection already 
    authenticates the token endpoint, and the token is delivered directly to 
    your server. An attacker cannot inject a forged token without compromising 
    TLS itself.
    
    This is the security model used by most OAuth2 server-side implementations.
    
    {2 When signature verification IS needed}
    
    You need cryptographic signature verification if:
    - The ID token passes through untrusted channels (e.g., browser, mobile app)
    - You accept tokens from sources other than the token endpoint
    - You're implementing implicit flow (not recommended)
    - You're validating tokens for a different application
    
    For these cases, use a dedicated JWT library like [jose] that supports
    JWKS (JSON Web Key Set) fetching and RSA/ECDSA signature verification.
    
    {2 What this module validates}
    
    - {b Issuer (iss)}: Token comes from expected provider
    - {b Audience (aud)}: Token is intended for your application  
    - {b Expiration (exp)}: Token hasn't expired
    - {b Issued-at (iat)}: Token wasn't issued in the future
    - {b Nonce}: Prevents replay attacks (when configured)
    
    These validations are {i required} even when signature verification is 
    performed, so this module is useful in all scenarios.
*)

(** {1 Types} *)

(** JWT header *)
type jwt_header = {
  alg : string;  (* Algorithm, e.g., "RS256" *)
  typ : string option;  (* Type, typically "JWT" *)
  kid : string option;  (* Key ID for looking up the signing key *)
}

(** Standard OIDC ID token claims *)
type id_token_claims = {
  iss : string;           (* Issuer *)
  sub : string;           (* Subject (user ID) *)
  aud : string list;      (* Audience (client ID(s)) *)
  exp : int;              (* Expiration time (Unix timestamp) *)
  iat : int;              (* Issued at time (Unix timestamp) *)
  nonce : string option;  (* Nonce for replay protection *)
  auth_time : int option; (* Time of authentication *)
  azp : string option;    (* Authorized party *)
  at_hash : string option;(* Access token hash *)
  email : string option;
  email_verified : bool option;
  name : string option;
  picture : string option;
  given_name : string option;
  family_name : string option;
  locale : string option;
}

(** Validation configuration *)
type validation_config = {
  issuer : string;              (* Expected issuer *)
  client_id : string;           (* Expected audience/client ID *)
  clock_skew_seconds : int;     (* Allowed clock skew (default 60) *)
  require_nonce : bool;         (* Whether nonce is required *)
  expected_nonce : string option; (* Expected nonce value if required *)
}

(** Validation errors *)
type validation_error =
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

(** {1 Utility Functions} *)

(** Convert validation error to string *)
let validation_error_to_string = function
  | Invalid_format msg -> Printf.sprintf "Invalid token format: %s" msg
  | Invalid_base64 msg -> Printf.sprintf "Invalid base64 encoding: %s" msg
  | Invalid_json msg -> Printf.sprintf "Invalid JSON: %s" msg
  | Missing_claim claim -> Printf.sprintf "Missing required claim: %s" claim
  | Invalid_issuer { expected; actual } -> 
      Printf.sprintf "Invalid issuer: expected '%s', got '%s'" expected actual
  | Invalid_audience { expected; actual } ->
      Printf.sprintf "Invalid audience: expected '%s', got [%s]" 
        expected (String.concat ", " actual)
  | Token_expired { exp; now } ->
      Printf.sprintf "Token expired: exp=%d, now=%d" exp now
  | Token_not_yet_valid { iat; now } ->
      Printf.sprintf "Token not yet valid: iat=%d, now=%d" iat now
  | Invalid_nonce { expected; actual } ->
      Printf.sprintf "Invalid nonce: expected '%s', got '%s'" 
        expected (Option.value actual ~default:"<none>")
  | Missing_nonce -> "Nonce required but not present in token"
  | Signature_verification_not_implemented ->
      "Signature verification not implemented - use external JWT library for production"
  | Algorithm_not_supported alg ->
      Printf.sprintf "Algorithm not supported: %s" alg

(** Base64-URL decode (handles missing padding) *)
let base64url_decode s =
  (* Add padding if necessary *)
  let padded = 
    let len = String.length s in
    let padding_needed = (4 - (len mod 4)) mod 4 in
    s ^ String.make padding_needed '='
  in
  (* Convert URL-safe alphabet to standard *)
  let standard = 
    String.map (function '-' -> '+' | '_' -> '/' | c -> c) padded
  in
  try
    Ok (Base64.decode_exn standard)
  with _ ->
    Error (Invalid_base64 s)

(** {1 Parsing Functions} *)

(** Parse JWT header from JSON *)
let parse_header json =
  try
    let open Yojson.Basic.Util in
    let alg = json |> member "alg" |> to_string in
    let typ = try Some (json |> member "typ" |> to_string) with _ -> None in
    let kid = try Some (json |> member "kid" |> to_string) with _ -> None in
    Ok { alg; typ; kid }
  with e ->
    Error (Invalid_json (Printexc.to_string e))

(** Parse ID token claims from JSON *)
let parse_claims json =
  try
    let open Yojson.Basic.Util in
    
    (* Required claims *)
    let iss = try json |> member "iss" |> to_string 
              with _ -> raise (Failure "iss") in
    let sub = try json |> member "sub" |> to_string 
              with _ -> raise (Failure "sub") in
    let exp = try json |> member "exp" |> to_int 
              with _ -> raise (Failure "exp") in
    let iat = try json |> member "iat" |> to_int 
              with _ -> raise (Failure "iat") in
    
    (* aud can be string or array *)
    let aud = 
      try 
        match json |> member "aud" with
        | `String s -> [s]
        | `List l -> List.map to_string l
        | _ -> raise (Failure "aud")
      with _ -> raise (Failure "aud")
    in
    
    (* Optional claims *)
    let nonce = try Some (json |> member "nonce" |> to_string) with _ -> None in
    let auth_time = try Some (json |> member "auth_time" |> to_int) with _ -> None in
    let azp = try Some (json |> member "azp" |> to_string) with _ -> None in
    let at_hash = try Some (json |> member "at_hash" |> to_string) with _ -> None in
    let email = try Some (json |> member "email" |> to_string) with _ -> None in
    let email_verified = try Some (json |> member "email_verified" |> to_bool) with _ -> None in
    let name = try Some (json |> member "name" |> to_string) with _ -> None in
    let picture = try Some (json |> member "picture" |> to_string) with _ -> None in
    let given_name = try Some (json |> member "given_name" |> to_string) with _ -> None in
    let family_name = try Some (json |> member "family_name" |> to_string) with _ -> None in
    let locale = try Some (json |> member "locale" |> to_string) with _ -> None in
    
    Ok { 
      iss; sub; aud; exp; iat; nonce; auth_time; azp; at_hash;
      email; email_verified; name; picture; given_name; family_name; locale 
    }
  with Failure claim ->
    Error (Missing_claim claim)
  | e ->
    Error (Invalid_json (Printexc.to_string e))

(** Decode and parse an ID token (without signature verification)
    
    @param token The raw JWT string
    @return Parsed header, claims, and signature (base64-encoded)
*)
let decode_id_token token =
  let parts = String.split_on_char '.' token in
  match parts with
  | [header_b64; payload_b64; signature_b64] ->
      (match base64url_decode header_b64 with
       | Error e -> Error e
       | Ok header_json ->
           match base64url_decode payload_b64 with
           | Error e -> Error e
           | Ok payload_json ->
               (try
                 let header = Yojson.Basic.from_string header_json in
                 let payload = Yojson.Basic.from_string payload_json in
                 match parse_header header, parse_claims payload with
                 | Ok h, Ok c -> Ok (h, c, signature_b64)
                 | Error e, _ -> Error e
                 | _, Error e -> Error e
               with e ->
                 Error (Invalid_json (Printexc.to_string e))))
  | _ ->
      Error (Invalid_format "JWT must have 3 parts separated by '.'")

(** {1 Validation Functions} *)

(** Create default validation config *)
let make_validation_config ~issuer ~client_id ?expected_nonce ?(clock_skew_seconds=60) () =
  {
    issuer;
    client_id;
    clock_skew_seconds;
    require_nonce = Option.is_some expected_nonce;
    expected_nonce;
  }

(** Validate issuer claim *)
let validate_issuer config claims =
  if claims.iss = config.issuer then
    Ok ()
  else
    Error (Invalid_issuer { expected = config.issuer; actual = claims.iss })

(** Validate audience claim *)
let validate_audience config claims =
  if List.mem config.client_id claims.aud then
    Ok ()
  else
    Error (Invalid_audience { expected = config.client_id; actual = claims.aud })

(** Validate expiration *)
let validate_expiration config claims =
  let now = int_of_float (Unix.time ()) in
  if claims.exp + config.clock_skew_seconds >= now then
    Ok ()
  else
    Error (Token_expired { exp = claims.exp; now })

(** Validate issued-at time (not in the future) *)
let validate_iat config claims =
  let now = int_of_float (Unix.time ()) in
  if claims.iat - config.clock_skew_seconds <= now then
    Ok ()
  else
    Error (Token_not_yet_valid { iat = claims.iat; now })

(** Validate nonce *)
let validate_nonce config claims =
  match config.require_nonce, config.expected_nonce, claims.nonce with
  | false, _, _ -> Ok ()
  | true, None, _ -> Ok ()  (* Config error - should have expected_nonce if require_nonce *)
  | true, Some _, None -> Error Missing_nonce
  | true, Some expected, Some actual ->
      if expected = actual then Ok ()
      else Error (Invalid_nonce { expected; actual = Some actual })

(** Validate ID token claims.
    
    This validates all standard OIDC claims:
    - Issuer matches expected value
    - Audience contains the client ID
    - Token is not expired (with configurable clock skew)
    - Token was not issued in the future
    - Nonce matches (if required)
    
    See the module documentation for when this is sufficient vs when you
    also need signature verification.
    
    @param config Validation configuration
    @param claims Parsed ID token claims
    @return Ok () if valid, Error with reason if invalid
*)
let validate_claims config claims =
  let validations = [
    validate_issuer config claims;
    validate_audience config claims;
    validate_expiration config claims;
    validate_iat config claims;
    validate_nonce config claims;
  ] in
  match List.find_opt Result.is_error validations with
  | Some (Error e) -> Error e
  | _ -> Ok ()

(** Decode and validate an ID token string.
    
    Parses the JWT, extracts claims, and validates them against the config.
    
    For tokens received directly from the provider's token endpoint over HTTPS,
    this provides complete validation. See the module documentation for the
    full security model explanation.
    
    @param config Validation configuration
    @param token Raw JWT string (base64url-encoded header.payload.signature)
    @return Ok claims if valid, Error with reason if invalid
    
    Example:
    {[
      let config = google_validation_config ~client_id:"your-client-id" () in
      match validate_id_token config token_response.id_token with
      | Ok claims -> 
          Printf.printf "User ID: %s\n" claims.sub;
          Printf.printf "Email: %s\n" (Option.value claims.email ~default:"N/A")
      | Error e -> 
          Printf.eprintf "Validation failed: %s\n" (validation_error_to_string e)
    ]}
*)
let validate_id_token config token =
  match decode_id_token token with
  | Error e -> Error e
  | Ok (_header, claims, _signature) ->
      match validate_claims config claims with
      | Error e -> Error e
      | Ok () -> Ok claims

(** {1 Provider-Specific Configurations} *)

(** Google OIDC issuer *)
let google_issuer = "https://accounts.google.com"

(** Microsoft OIDC issuers (varies by tenant) *)
let microsoft_issuer_common = "https://login.microsoftonline.com/common/v2.0"
let microsoft_issuer_consumers = "https://login.microsoftonline.com/consumers/v2.0"
let microsoft_issuer_organizations = "https://login.microsoftonline.com/organizations/v2.0"

(** Create validation config for Google *)
let google_validation_config ~client_id ?expected_nonce () =
  make_validation_config ~issuer:google_issuer ~client_id ?expected_nonce ()

(** Create validation config for Microsoft (common tenant)
    
    Note: Microsoft tokens may have tenant-specific issuers.
    For single-tenant apps, use the specific tenant issuer.
*)
let microsoft_validation_config ~client_id ~tenant ?expected_nonce () =
  let issuer = Printf.sprintf "https://login.microsoftonline.com/%s/v2.0" tenant in
  make_validation_config ~issuer ~client_id ?expected_nonce ()

(** {1 Convenience Functions} *)

(** Extract user info from validated ID token claims.
    
    Converts OIDC standard claims to the library's [user_info] type.
    This is useful when you want to use claims from the ID token instead
    of making a separate userinfo endpoint call.
    
    @param provider The OAuth provider (e.g., [Google], [Microsoft])
    @param claims Validated ID token claims
    @return User info record
*)
let user_info_from_claims ~provider claims =
  Auth_types.{
    provider;
    provider_user_id = claims.sub;
    email = claims.email;
    email_verified = claims.email_verified;
    name = claims.name;
    given_name = claims.given_name;
    family_name = claims.family_name;
    username = None;
    avatar_url = claims.picture;
    locale = claims.locale;
    raw_response = `Assoc [
      ("sub", `String claims.sub);
      ("iss", `String claims.iss);
      ("email", match claims.email with Some e -> `String e | None -> `Null);
    ];
  }

(** {1 Token Source Validation} *)

(** Indicates how an ID token was obtained, which determines whether 
    signature verification is needed. *)
type token_source =
  | Direct_from_token_endpoint
    (** Token received directly from provider's token endpoint over HTTPS.
        Signature verification is NOT needed - TLS provides authentication. *)
  | From_untrusted_source
    (** Token passed through browser, mobile app, or other untrusted channel.
        Signature verification IS needed - use an external JWT library. *)

(** Validate an ID token with explicit token source.
    
    This function makes the security model explicit by requiring you to
    specify how the token was obtained.
    
    @param source How the token was obtained
    @param config Validation configuration
    @param token Raw JWT string
    @return Ok claims if valid, Error with reason if invalid
    @raise Invalid_argument if source is [From_untrusted_source] (use external JWT library)
    
    Example for server-side OAuth2 flow:
    {[
      (* Token received from exchange_code_for_tokens - safe to validate *)
      let config = google_validation_config ~client_id () in
      match validate_id_token_from_source 
              ~source:Direct_from_token_endpoint config id_token with
      | Ok claims -> (* use claims *)
      | Error e -> (* handle error *)
    ]}
*)
let validate_id_token_from_source ~source config token =
  match source with
  | Direct_from_token_endpoint ->
      validate_id_token config token
  | From_untrusted_source ->
      Error (Invalid_format 
        "Tokens from untrusted sources require signature verification. \
         Use an external JWT library (e.g., jose) with JWKS support.")
