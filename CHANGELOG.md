# Changelog

All notable changes to this project will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

---

## [Unreleased]

---

## [1.0.0] — 2026-03-11

### Added
- `certify` step — route any HTTP call through ArkForge and get a cryptographic proof
- Ed25519 signature of the full request+response bundle
- RFC 3161 timestamp via FreeTSA
- Sigstore Rekor immutable log anchor
- `proof_id`, `verification_url`, `chain_hash` as step outputs
- Free tier: 500 proofs/month

[Unreleased]: https://github.com/ark-forge/trust-proof-action/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ark-forge/trust-proof-action/releases/tag/v1.0.0
