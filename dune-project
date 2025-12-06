(lang dune 3.17)
(name ocaml-oauth2-clients)

(generate_opam_files true)

(source (github makerprism/ocaml-oauth2-clients))
(license MIT)
(authors "Sabine Schmaltz")
(maintainers "sabine@makerprism.com")
(homepage "https://github.com/makerprism/ocaml-oauth2-clients")
(documentation "https://github.com/makerprism/ocaml-oauth2-clients")
(bug_reports "https://github.com/makerprism/ocaml-oauth2-clients/issues")

(package
 (name oauth2-client)
 (synopsis "Runtime-agnostic OAuth2 client library")
 (description "Runtime-agnostic, HTTP-client-agnostic OAuth2 client library with PKCE support. Provides core abstractions for implementing OAuth2 login flows with various providers (Google, GitHub, etc.). Can be used with any async runtime (Lwt, Eio, synchronous) and any HTTP client library. RNG is pluggable - users provide their own cryptographically secure random number generator.")
 (depends
  (ocaml (>= 4.14))
  (dune (>= 3.0))
  yojson
  digestif
  base64))

(package
 (name oauth2-client-lwt)
 (synopsis "Lwt runtime adapter for oauth2-client")
 (description "Lwt runtime adapter for oauth2-client with Cohttp_lwt_unix HTTP client implementation. Provides a ready-to-use OAuth2 implementation for Lwt-based applications.")
 (depends
  (ocaml (>= 4.14))
  (dune (>= 3.0))
  oauth2-client
  lwt
  cohttp-lwt-unix
  uri))

(package
 (name oauth2-github)
 (synopsis "GitHub OAuth2 provider for oauth2-client")
 (description "GitHub OAuth2 provider for oauth2-client. Implements OAuth 2.0 with PKCE for secure GitHub Sign-In. Supports retrieving user profile information including email, name, and avatar.")
 (depends
  (ocaml (>= 4.14))
  (dune (>= 3.0))
  oauth2-client
  yojson))

(package
 (name oauth2-google)
 (synopsis "Google OAuth2 provider for oauth2-client")
 (description "Google OAuth2 provider for oauth2-client. Implements OAuth 2.0 with PKCE for secure Google Sign-In. Supports OpenID Connect with email, profile, and ID token retrieval.")
 (depends
  (ocaml (>= 4.14))
  (dune (>= 3.0))
  oauth2-client
  yojson))

(package
 (name oauth2-microsoft)
 (synopsis "Microsoft/Azure AD OAuth2 provider for oauth2-client")
 (description "Microsoft/Azure AD OAuth2 provider for oauth2-client. Implements OAuth 2.0 with PKCE for secure Microsoft Account and Azure AD Sign-In. Supports OpenID Connect with email, profile, and ID token retrieval.")
 (depends
  (ocaml (>= 4.14))
  (dune (>= 3.0))
  oauth2-client
  yojson))
