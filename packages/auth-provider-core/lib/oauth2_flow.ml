(** OAuth2 Flow - Runtime-agnostic OAuth2 authentication flow *)

open Auth_types

(** {1 URI Encoding} *)

(** Module for URI encoding *)
module Uri = struct
  type component = [ `Query ]
  
  (** Percent-encode a string for use in URLs *)
  let pct_encode ?(component=`Query) str =
    let _ = component in (* Unused but kept for API compatibility *)
    let buf = Buffer.create (String.length str * 3) in
    String.iter (fun c ->
      match c with
      | 'A'..'Z' | 'a'..'z' | '0'..'9' | '-' | '_' | '.' | '~' ->
          Buffer.add_char buf c
      | _ ->
          Buffer.add_string buf (Printf.sprintf "%%%02X" (Char.code c))
    ) str;
    Buffer.contents buf
end

(** {1 HTTP Client Interface} *)

(** Runtime-agnostic HTTP client interface using CPS style *)
module type HTTP_CLIENT = sig
  (** Make a POST request
      @param url The URL to request
      @param headers HTTP headers
      @param body Request body
      @param on_success Success continuation receiving the response
      @param on_error Error continuation receiving error message
  *)
  val post : 
    url:string ->
    headers:(string * string) list -> 
    body:string -> 
    on_success:(http_response -> unit) -> 
    on_error:(string -> unit) -> 
    unit
  
  (** Make a GET request
      @param url The URL to request
      @param headers HTTP headers
      @param on_success Success continuation receiving the response
      @param on_error Error continuation receiving error message
  *)
  val get : 
    url:string ->
    headers:(string * string) list -> 
    on_success:(http_response -> unit) -> 
    on_error:(string -> unit) -> 
    unit
end

(** {1 URL Building} *)

(** Build authorization URL with PKCE 
    
    @param config Provider configuration
    @param state CSRF protection token
    @param code_challenge PKCE code challenge
    @return Authorization URL to redirect user to
*)
let build_authorization_url config ~state ~code_challenge =
  let scope_str = String.concat " " config.scopes in
  let base_params = [
    ("response_type", "code");
    ("client_id", config.client_id);
    ("redirect_uri", config.redirect_uri);
    ("scope", scope_str);
    ("state", state);
    ("code_challenge", code_challenge);
    ("code_challenge_method", "S256");
  ] in
  let all_params = base_params @ config.extra_auth_params in
  let encode_param (k, v) = 
    Printf.sprintf "%s=%s" k (Uri.pct_encode ~component:`Query v) 
  in
  let query_string = 
    all_params
    |> List.map encode_param
    |> String.concat "&"
  in
  Printf.sprintf "%s?%s" config.auth_endpoint query_string

(** {1 OAuth2 Flow Implementation} *)

(** Make an OAuth2 flow implementation given an HTTP client *)
module Make (Http : HTTP_CLIENT) = struct
  
  (** Start OAuth2 authorization flow
      
      @param config Provider configuration
      @return OAuth state and authorization URL
  *)
  let start_authorization_flow config =
    let state = Pkce.generate_state () in
    let code_verifier = Pkce.generate_code_verifier () in
    let code_challenge = Pkce.generate_code_challenge code_verifier in
    let auth_url = build_authorization_url config ~state ~code_challenge in
    let now = Unix.time () in
    let oauth_state = {
      state;
      code_verifier;
      provider = config.provider;
      redirect_uri = config.redirect_uri;
      created_at = now;
      expires_at = now +. (15. *. 60.); (* 15 minutes *)
      custom_data = None;
    } in
    (oauth_state, auth_url)
  
  (** Exchange authorization code for tokens
      
      @param config Provider configuration
      @param code Authorization code from callback
      @param code_verifier PKCE code verifier
      @param on_success Success continuation receiving token response
      @param on_error Error continuation receiving error message
  *)
  let exchange_code_for_tokens config ~code ~code_verifier ~on_success ~on_error =
    let body_params = [
      ("code", code);
      ("grant_type", "authorization_code");
      ("client_id", config.client_id);
      ("redirect_uri", config.redirect_uri);
      ("code_verifier", code_verifier);
    ] in
    
    (* Add client_secret if provided (some providers require it) *)
    let body_params = match config.client_secret with
      | Some secret -> ("client_secret", secret) :: body_params
      | None -> body_params
    in
    
    let body_str = 
      body_params
      |> List.map (fun (k, v) -> 
          Printf.sprintf "%s=%s" k (Uri.pct_encode ~component:`Query v))
      |> String.concat "&"
    in
    
    let headers = [
      ("Content-Type", "application/x-www-form-urlencoded");
      ("Accept", "application/json");
    ] in
    
    Http.post
      ~url:config.token_endpoint
      ~headers
      ~body:body_str
      ~on_success:(fun response ->
        if response.status = 200 then
          match Yojson.Basic.from_string response.body |> parse_token_response with
          | Ok token -> on_success token
          | Error err -> on_error err
        else
          on_error (Printf.sprintf "Token exchange failed with status %d: %s" 
                     response.status response.body)
      )
      ~on_error
  
  (** Refresh access token using refresh token
      
      @param config Provider configuration
      @param refresh_token The refresh token
      @param on_success Success continuation receiving new token response
      @param on_error Error continuation receiving error message
  *)
  let refresh_access_token config ~refresh_token ~on_success ~on_error =
    let body_params = [
      ("refresh_token", refresh_token);
      ("grant_type", "refresh_token");
      ("client_id", config.client_id);
    ] in
    
    (* Add client_secret if provided *)
    let body_params = match config.client_secret with
      | Some secret -> ("client_secret", secret) :: body_params
      | None -> body_params
    in
    
    let body_str = 
      body_params
      |> List.map (fun (k, v) -> 
          Printf.sprintf "%s=%s" k (Uri.pct_encode ~component:`Query v))
      |> String.concat "&"
    in
    
    let headers = [
      ("Content-Type", "application/x-www-form-urlencoded");
      ("Accept", "application/json");
    ] in
    
    Http.post
      ~url:config.token_endpoint
      ~headers
      ~body:body_str
      ~on_success:(fun response ->
        if response.status = 200 then
          match Yojson.Basic.from_string response.body |> parse_token_response with
          | Ok token -> on_success token
          | Error err -> on_error err
        else
          on_error (Printf.sprintf "Token refresh failed with status %d: %s" 
                     response.status response.body)
      )
      ~on_error
  
  (** Get user information using access token
      
      @param config Provider configuration
      @param access_token The access token
      @param parse_user_info Provider-specific user info parser
      @param on_success Success continuation receiving user info
      @param on_error Error continuation receiving error message
  *)
  let get_user_info config ~access_token ~parse_user_info ~on_success ~on_error =
    let headers = [
      ("Authorization", Printf.sprintf "Bearer %s" access_token);
      ("Accept", "application/json");
    ] in
    
    Http.get
      ~url:config.user_info_endpoint
      ~headers
      ~on_success:(fun response ->
        if response.status = 200 then
          match parse_user_info response.body with
          | Ok user_info -> on_success user_info
          | Error err -> on_error err
        else
          on_error (Printf.sprintf "User info request failed with status %d: %s" 
                     response.status response.body)
      )
      ~on_error
  
  (** Complete OAuth2 flow: exchange code and get user info
      
      @param config Provider configuration
      @param code Authorization code
      @param code_verifier PKCE code verifier
      @param parse_user_info Provider-specific user info parser
      @param on_success Success continuation receiving (token_response, user_info)
      @param on_error Error continuation receiving error message
  *)
  let complete_oauth_flow config ~code ~code_verifier ~parse_user_info ~on_success ~on_error =
    exchange_code_for_tokens config ~code ~code_verifier
      ~on_success:(fun token_response ->
        get_user_info config 
          ~access_token:token_response.access_token
          ~parse_user_info
          ~on_success:(fun user_info ->
            on_success (token_response, user_info)
          )
          ~on_error
      )
      ~on_error
end
