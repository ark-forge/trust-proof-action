# ArkForge Trust Proof Action

Generate cryptographic timestamp proofs for your CI/CD pipeline. Every proof is **Ed25519 signed**, **RFC 3161 timestamped**, and **publicly verifiable**.

Prove that a file, build artifact, or release existed at a specific point in time — with three independent witnesses.

## Quick start

```yaml
- uses: ark-forge/trust-proof-action@v1
  with:
    file: dist/my-package.tar.gz
    api-key: ${{ secrets.ARKFORGE_API_KEY }}
```

## Get a free API key

```bash
curl -X POST https://trust.arkforge.tech/v1/keys/free-signup \
  -H "Content-Type: application/json" \
  -d '{"email": "you@example.com"}'
```

Free tier: 100 proofs/month, no credit card required.

> **CI tip:** For repos with frequent pushes, run the proof only on releases or tagged commits to stay within limits. Use `on: release` or `if: startsWith(github.ref, 'refs/tags/')` to filter. Need more? Buy credits at [arkforge.tech/trust](https://arkforge.tech/trust) — pay-per-proof, no subscription.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `file` | One of `file` or `hash` | Path to file to prove (SHA-256 computed automatically) |
| `hash` | One of `file` or `hash` | Precomputed SHA-256 hash to timestamp |
| `api-key` | Yes | ArkForge Trust Layer API key |
| `description` | No | Optional text attached to the proof |

## Outputs

| Output | Description |
|--------|-------------|
| `proof-id` | Unique proof identifier (e.g. `prf_20260228_...`) |
| `proof-url` | Public verification URL |
| `chain-hash` | SHA-256 chain hash binding all proof elements |
| `timestamp` | ISO 8601 UTC timestamp |
| `file-hash` | SHA-256 of the input file |
| `badge` | Markdown badge linking to the proof |

## Examples

### Prove a release artifact

```yaml
name: Release with Trust Proof
on:
  release:
    types: [published]

jobs:
  prove:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: make build

      - name: Timestamp proof
        id: proof
        uses: ark-forge/trust-proof-action@v1
        with:
          file: dist/release.tar.gz
          api-key: ${{ secrets.ARKFORGE_API_KEY }}
          description: "Release ${{ github.ref_name }}"

      - name: Add proof to release notes
        run: |
          echo "Trust Proof: ${{ steps.proof.outputs.proof-url }}" >> $GITHUB_STEP_SUMMARY
```

### Prove a commit hash

```yaml
- name: Timestamp current commit
  uses: ark-forge/trust-proof-action@v1
  with:
    hash: ${{ github.sha }}
    api-key: ${{ secrets.ARKFORGE_API_KEY }}
    description: "Commit on ${{ github.ref_name }}"
```

### Only on tags (save free tier quota)

```yaml
- name: Timestamp release
  if: startsWith(github.ref, 'refs/tags/')
  uses: ark-forge/trust-proof-action@v1
  with:
    file: dist/release.tar.gz
    api-key: ${{ secrets.ARKFORGE_API_KEY }}
```

### Use the badge

```yaml
- name: Generate proof
  id: proof
  uses: ark-forge/trust-proof-action@v1
  with:
    file: build/output.wasm
    api-key: ${{ secrets.ARKFORGE_API_KEY }}

- name: Show badge
  run: echo "${{ steps.proof.outputs.badge }}"
```

## What's in a proof?

Each proof contains:

- **SHA-256 hash chain** — binds request, response, payment, and timestamp into one verifiable seal
- **Ed25519 signature** — signed by ArkForge's key ([verify](https://arkforge.tech/trust/v1/pubkey))
- **RFC 3161 timestamp** — independent timestamp authority (FreeTSA.org)

Two independent witnesses. One curl.

## Verification

Every proof has a public URL. Open it in a browser or fetch the JSON:

```bash
curl https://arkforge.tech/trust/v1/proof/prf_20260228_123456_abc123
```

Download the RFC 3161 timestamp for offline verification:

```bash
curl https://arkforge.tech/trust/v1/proof/prf_20260228_123456_abc123/tsr -o proof.tsr
```

## License

MIT
