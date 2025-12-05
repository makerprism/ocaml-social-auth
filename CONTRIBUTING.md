# Contributing to ocaml-social-auth

Thank you for your interest in contributing!

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/makerprism/ocaml-social-auth.git
   cd ocaml-social-auth
   ```

2. Install dependencies:
   ```bash
   opam install . --deps-only --with-test
   ```

3. Build:
   ```bash
   make build
   # or
   dune build
   ```

4. Run tests:
   ```bash
   make test
   # or
   dune runtest
   ```

## Project Structure

```
ocaml-social-auth/
├── packages/
│   ├── auth-provider-core/      # Core abstractions
│   ├── auth-provider-lwt/       # Lwt runtime
│   ├── auth-provider-github-v2/ # GitHub OAuth
│   ├── auth-provider-google-v2/ # Google OAuth
│   └── auth-provider-microsoft-v2/ # Microsoft OAuth
├── dune-project
├── dune-workspace
└── Makefile
```

## Adding a New Provider

1. Create a new directory: `packages/auth-provider-<name>-v<version>/`
2. Add `dune-project` with package metadata
3. Implement the provider in `lib/`
4. Add tests in `test/`
5. Update the root README

## Code Style

- Follow OCaml conventions
- Use meaningful names
- Add documentation comments for public APIs
- Keep functions small and focused

## Pull Request Process

1. Create a feature branch
2. Make your changes
3. Ensure tests pass
4. Update documentation if needed
5. Submit a PR with a clear description

## Releasing

Releases are created by pushing tags in the format `<package>@<version>`:

```bash
git tag auth-provider-core@0.2.0
git push origin auth-provider-core@0.2.0
```

This triggers the release workflow automatically.
