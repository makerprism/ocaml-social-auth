(** PKCE (Proof Key for Code Exchange) Implementation *)

(** {1 PKCE Module Signature} *)

(** Output signature for the PKCE functor *)
module type S = sig
  (** Generate code_verifier (43-128 characters of unreserved chars)
      
      Per RFC 7636: code_verifier = 43*128unreserved
      unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
      
      Uses 128 characters for maximum entropy (96 bytes of entropy) *)
  val generate_code_verifier : unit -> string

  (** Generate code_challenge from code_verifier using SHA256
      
      code_challenge = BASE64URL(SHA256(ASCII(code_verifier)))
      
      @param verifier The code_verifier string
      @return Base64-URL encoded SHA256 hash without padding *)
  val generate_code_challenge : string -> string

  (** Generate OAuth state for CSRF protection (32 characters minimum)
      
      This is separate from PKCE but used together in OAuth2 flows. *)
  val generate_state : unit -> string

  (** Validate code_verifier length (43-128 characters) *)
  val validate_code_verifier : string -> bool

  (** Validate state token length (minimum 32 characters recommended) *)
  val validate_state : string -> bool
end

(** {1 PKCE Functor} *)

(** Create a PKCE module with the given random number generator.
    
    Example usage:
    {[
      module My_rng : Auth_types.RNG = struct
        let generate n = 
          let buf = Bytes.create n in
          (* fill with cryptographically secure random bytes *)
          buf
      end
      
      module Pkce = Pkce.Make(My_rng)
      
      let verifier = Pkce.generate_code_verifier ()
      let challenge = Pkce.generate_code_challenge verifier
    ]}
*)
module Make (Rng : Auth_types.RNG) : S = struct
  (** Characters allowed in code_verifier (unreserved characters) *)
  let unreserved_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"

  (** Generate cryptographically secure random string from allowed character set.
      
      SECURITY: Uses the provided RNG for cryptographic randomness.
      This is critical for PKCE security - predictable code_verifiers would
      allow attackers to bypass PKCE protection entirely. *)
  let generate_random_string length =
    let chars_len = String.length unreserved_chars in
    let random_bytes = Rng.generate length in
    String.init length (fun i -> 
      let byte = Bytes.get_uint8 random_bytes i in
      String.get unreserved_chars (byte mod chars_len))

  let generate_code_verifier () =
    generate_random_string 128

  let generate_code_challenge verifier =
    let hash = Digestif.SHA256.digest_string verifier in
    let raw_hash = Digestif.SHA256.to_raw_string hash in
    (* Base64 URL encode without padding as per RFC 7636 *)
    Base64.encode_exn ~pad:false ~alphabet:Base64.uri_safe_alphabet raw_hash

  let generate_state () =
    generate_random_string 32

  let validate_code_verifier verifier =
    let len = String.length verifier in
    len >= 43 && len <= 128

  let validate_state state =
    String.length state >= 32
end
