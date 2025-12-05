(** PKCE (Proof Key for Code Exchange) Implementation *)

(** {1 Random String Generation} *)

(** Characters allowed in code_verifier (unreserved characters) *)
let unreserved_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"

(** Generate cryptographically secure random string from allowed character set.
    
    SECURITY: Uses Mirage_crypto_rng for cryptographic randomness.
    This is critical for PKCE security - predictable code_verifiers would
    allow attackers to bypass PKCE protection entirely. *)
let generate_random_string length =
  let chars_len = String.length unreserved_chars in
  let random_bytes = Mirage_crypto_rng.generate length in
  String.init length (fun i -> 
    let byte = Cstruct.get_uint8 random_bytes i in
    String.get unreserved_chars (byte mod chars_len))

(** {1 PKCE Code Verifier and Challenge} *)

(** Generate code_verifier (43-128 characters of unreserved chars)
    
    Per RFC 7636: code_verifier = 43*128unreserved
    unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
    
    We use 128 characters for maximum entropy (96 bytes of entropy)
*)
let generate_code_verifier () =
  generate_random_string 128

(** Generate code_challenge from code_verifier using SHA256
    
    code_challenge = BASE64URL(SHA256(ASCII(code_verifier)))
    
    @param verifier The code_verifier string
    @return Base64-URL encoded SHA256 hash without padding
*)
let generate_code_challenge verifier =
  let hash = Digestif.SHA256.digest_string verifier in
  let raw_hash = Digestif.SHA256.to_raw_string hash in
  (* Base64 URL encode without padding as per RFC 7636 *)
  Base64.encode_exn ~pad:false ~alphabet:Base64.uri_safe_alphabet raw_hash

(** {1 CSRF State Token} *)

(** Generate OAuth state for CSRF protection (32 characters minimum)
    
    This is separate from PKCE but used together in OAuth2 flows.
*)
let generate_state () =
  generate_random_string 32

(** {1 Validation} *)

(** Validate code_verifier length (43-128 characters) *)
let validate_code_verifier verifier =
  let len = String.length verifier in
  len >= 43 && len <= 128

(** Validate state token length (minimum 32 characters recommended) *)
let validate_state state =
  String.length state >= 32
