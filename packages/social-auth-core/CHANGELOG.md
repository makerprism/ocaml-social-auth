# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-11-27

### Added
- Initial release of social-auth-core
- Runtime-agnostic OAuth2 authentication library
- PKCE (RFC 7636) support for secure authorization code flow
- Continuation-passing style (CPS) interface for runtime flexibility
- Core types: `provider`, `token_response`, `user_info`, `oauth_state`
- PKCE utilities: code verifier and challenge generation
- OAuth2 flow implementation: authorization, token exchange, token refresh
- OpenID Connect support with ID token handling
- HTTP-client-agnostic interface
- Comprehensive type safety with result types
- Zero runtime dependencies (only yojson, digestif, base64 for utilities)

### Security
- Implemented PKCE for all OAuth2 flows
- CSRF protection via state parameter
- Support for client-secret-free flows (mobile/SPA apps)
