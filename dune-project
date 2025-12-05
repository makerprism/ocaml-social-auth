(lang dune 3.17)
(name ocaml-social-auth)

(generate_opam_files true)

(source (github makerprism/ocaml-social-auth))
(license MIT)
(authors "FeedMansion Team")
(maintainers "team@feedmansion.com")
(homepage "https://github.com/makerprism/ocaml-social-auth")
(documentation "https://github.com/makerprism/ocaml-social-auth")
(bug_reports "https://github.com/makerprism/ocaml-social-auth/issues")

(package
 (name social-auth-core)
 (synopsis "Runtime-agnostic OAuth2 authentication library")
 (description "Runtime-agnostic, HTTP-client-agnostic OAuth2 authentication library with PKCE support. Provides core abstractions for implementing OAuth2 login flows with various providers (Google, GitHub, etc.). Can be used with any async runtime (Lwt, Eio, synchronous) and any HTTP client library.")
 (depends
  (ocaml (>= 4.14))
  (dune (>= 3.0))
  yojson
  digestif
  base64
  cstruct
  (mirage-crypto-rng (< 1.0.0))))

(package
 (name social-auth-lwt)
 (synopsis "Lwt runtime adapter for social-auth-core")
 (description "Lwt runtime adapter for social-auth-core with Cohttp_lwt_unix HTTP client implementation. Provides a ready-to-use OAuth2 implementation for Lwt-based applications.")
 (depends
  (ocaml (>= 4.14))
  (dune (>= 3.0))
  social-auth-core
  lwt
  cohttp-lwt-unix
  uri))

(package
 (name social-auth-github-v2)
 (synopsis "GitHub OAuth2 authentication provider")
 (description "GitHub OAuth2 authentication provider for social-auth-core. Implements OAuth 2.0 with PKCE for secure GitHub Sign-In. Supports retrieving user profile information including email, name, and avatar.")
 (depends
  (ocaml (>= 4.14))
  (dune (>= 3.0))
  social-auth-core
  yojson))

(package
 (name social-auth-google-v2)
 (synopsis "Google OAuth2 authentication provider")
 (description "Google OAuth2 authentication provider for social-auth-core. Implements OAuth 2.0 with PKCE for secure Google Sign-In. Supports OpenID Connect with email, profile, and ID token retrieval.")
 (depends
  (ocaml (>= 4.14))
  (dune (>= 3.0))
  social-auth-core
  yojson))

(package
 (name social-auth-microsoft-v2)
 (synopsis "Microsoft/Azure AD OAuth2 authentication provider")
 (description "Microsoft/Azure AD OAuth2 authentication provider for social-auth-core. Implements OAuth 2.0 with PKCE for secure Microsoft Account and Azure AD Sign-In. Supports OpenID Connect with email, profile, and ID token retrieval.")
 (depends
  (ocaml (>= 4.14))
  (dune (>= 3.0))
  social-auth-core
  yojson))
