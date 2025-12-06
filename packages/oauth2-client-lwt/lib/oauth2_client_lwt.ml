(** Lwt Runtime Adapter for oauth2-client *)

open Lwt.Syntax
open Oauth2_client

(** {1 Random Number Generator} *)

(** Unix-based cryptographically secure RNG using /dev/urandom.
    
    This implementation reads from /dev/urandom which is available
    on Linux, macOS, and BSD systems. It provides cryptographically
    secure random bytes suitable for PKCE and CSRF tokens.
*)
module Rng : RNG = struct
  let urandom_fd = ref None
  
  let get_urandom_fd () =
    match !urandom_fd with
    | Some fd -> fd
    | None ->
      let fd = Unix.openfile "/dev/urandom" [Unix.O_RDONLY] 0 in
      urandom_fd := Some fd;
      fd
  
  let generate n =
    let fd = get_urandom_fd () in
    let buf = Bytes.create n in
    let rec read_all offset remaining =
      if remaining > 0 then begin
        let bytes_read = Unix.read fd buf offset remaining in
        if bytes_read = 0 then
          failwith "Failed to read from /dev/urandom"
        else
          read_all (offset + bytes_read) (remaining - bytes_read)
      end
    in
    read_all 0 n;
    buf
end

(** {1 PKCE Module} *)

(** Ready-to-use PKCE implementation using Unix /dev/urandom *)
module Pkce = Oauth2_client.Make_pkce(Rng)

(** {1 HTTP Client Implementation} *)

(** Cohttp_lwt_unix HTTP client for oauth2-client *)
module Http_client : HTTP_CLIENT = struct
  
  (** Make a POST request using Cohttp_lwt_unix *)
  let post ~url ~headers ~body ~on_success ~on_error =
    Lwt.async (fun () ->
      Lwt.catch
        (fun () ->
          let open Cohttp in
          let open Cohttp_lwt_unix in
          
          let headers = Header.of_list headers in
          let uri = Uri.of_string url in
          let body = Cohttp_lwt.Body.of_string body in
          
          let* (resp, resp_body) = Client.post ~headers ~body uri in
          let* body_str = Cohttp_lwt.Body.to_string resp_body in
          
          let status = Response.status resp |> Code.code_of_status in
          let resp_headers = Response.headers resp |> Header.to_list in
          
          let http_response = {
            status;
            headers = resp_headers;
            body = body_str;
          } in
          
          on_success http_response;
          Lwt.return_unit
        )
        (fun exn ->
          on_error (Printf.sprintf "HTTP POST failed: %s" (Printexc.to_string exn));
          Lwt.return_unit
        )
    )
  
  (** Make a GET request using Cohttp_lwt_unix *)
  let get ~url ~headers ~on_success ~on_error =
    Lwt.async (fun () ->
      Lwt.catch
        (fun () ->
          let open Cohttp in
          let open Cohttp_lwt_unix in
          
          let headers = Header.of_list headers in
          let uri = Uri.of_string url in
          
          let* (resp, resp_body) = Client.get ~headers uri in
          let* body_str = Cohttp_lwt.Body.to_string resp_body in
          
          let status = Response.status resp |> Code.code_of_status in
          let resp_headers = Response.headers resp |> Header.to_list in
          
          let http_response = {
            status;
            headers = resp_headers;
            body = body_str;
          } in
          
          on_success http_response;
          Lwt.return_unit
        )
        (fun exn ->
          on_error (Printf.sprintf "HTTP GET failed: %s" (Printexc.to_string exn));
          Lwt.return_unit
        )
    )
end

(** {1 OAuth2 Flow with Lwt} *)

(** OAuth2 flow implementation using Lwt and Cohttp *)
module Oauth2 = Make_oauth2_flow(Http_client)(Pkce)

(** {1 Convenience Functions} *)

(** Generate PKCE code verifier *)
let generate_code_verifier = Pkce.generate_code_verifier

(** Generate PKCE code challenge from verifier *)
let generate_code_challenge = Pkce.generate_code_challenge

(** Generate CSRF state token *)
let generate_state = Pkce.generate_state

(** {1 Lwt-friendly Wrappers} *)

(** Start OAuth2 authorization flow (synchronous, no Lwt needed) *)
let start_authorization_flow = Oauth2.start_authorization_flow

(** Exchange authorization code for tokens (Lwt wrapper)
    
    @param config Provider configuration
    @param code Authorization code from callback
    @param code_verifier PKCE code verifier
    @return Lwt promise with token response or error
*)
let exchange_code_for_tokens config ~code ~code_verifier =
  let promise, resolver = Lwt.wait () in
  Oauth2.exchange_code_for_tokens
    config
    ~code
    ~code_verifier
    ~on_success:(fun token -> Lwt.wakeup_later resolver (Ok token))
    ~on_error:(fun err -> Lwt.wakeup_later resolver (Error err));
  promise

(** Refresh access token (Lwt wrapper)
    
    @param config Provider configuration
    @param refresh_token The refresh token
    @return Lwt promise with new token response or error
*)
let refresh_access_token config ~refresh_token =
  let promise, resolver = Lwt.wait () in
  Oauth2.refresh_access_token
    config
    ~refresh_token
    ~on_success:(fun token -> Lwt.wakeup_later resolver (Ok token))
    ~on_error:(fun err -> Lwt.wakeup_later resolver (Error err));
  promise

(** Get user information (Lwt wrapper)
    
    @param config Provider configuration
    @param access_token The access token
    @param parse_user_info Provider-specific user info parser
    @return Lwt promise with user info or error
*)
let get_user_info config ~access_token ~parse_user_info =
  let promise, resolver = Lwt.wait () in
  Oauth2.get_user_info
    config
    ~access_token
    ~parse_user_info
    ~on_success:(fun user_info -> Lwt.wakeup_later resolver (Ok user_info))
    ~on_error:(fun err -> Lwt.wakeup_later resolver (Error err));
  promise

(** Complete OAuth2 flow: exchange code and get user info (Lwt wrapper)
    
    @param config Provider configuration
    @param code Authorization code
    @param code_verifier PKCE code verifier
    @param parse_user_info Provider-specific user info parser
    @return Lwt promise with (token_response, user_info) or error
*)
let complete_oauth_flow config ~code ~code_verifier ~parse_user_info =
  let promise, resolver = Lwt.wait () in
  Oauth2.complete_oauth_flow
    config
    ~code
    ~code_verifier
    ~parse_user_info
    ~on_success:(fun result -> Lwt.wakeup_later resolver (Ok result))
    ~on_error:(fun err -> Lwt.wakeup_later resolver (Error err));
  promise

(** {1 Re-exports from Core} *)

(** Re-export core types for convenience *)
module Types = struct
  type provider = Oauth2_client.provider =
    | Google
    | GitHub
    | Microsoft
    | Custom of string

  type token_response = Oauth2_client.token_response = {
    access_token : string;
    token_type : string;
    expires_in : int option;
    refresh_token : string option;
    scope : string option;
    id_token : string option;
  }

  type user_info = Oauth2_client.user_info = {
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

  type oauth_state = Oauth2_client.oauth_state = {
    state : string;
    code_verifier : string;
    provider : provider;
    redirect_uri : string;
    created_at : float;
    expires_at : float;
    custom_data : string option;
  }

  type provider_config = Oauth2_client.provider_config = {
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
end
