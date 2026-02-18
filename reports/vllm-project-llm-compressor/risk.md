# Risk Assessment

> **Written to**: risk.md

## Bus Factor

| Metric | Value |
|--------|-------|
| Total known contributors | 15+ |
| Top-1 contributor share | ~17% (markurtz) |
| Top-3 contributor share | ~48% |
| Core team (top 5) | markurtz, bfineran, kylesayrs, dsikka, rahul-tuli |

**Assessment: Moderate bus factor risk.** The top 3 contributors hold ~48% of commit history, which is typical for a small team library. The risk is mitigated by:
- All top contributors appear to be Red Hat employees — organizational continuity
- The team has not been concentrated on a single person (top-1 at 17% is not dangerous)
- If key individuals leave Red Hat, replacement contributors can be sourced internally

**Flag**: If Red Hat were to de-prioritize or discontinue their AI investment, the project could see significant contributor drop-off. This is a business risk, not a technical one.

## API Stability

- **Version**: Still in 0.x (v0.9.x) — no API stability guarantees
- **CHANGELOG**: Not present in the repo. Breaking changes must be tracked via release notes and commit history.
- **Migration burden**: The primary API (`oneshot`, `QuantizationModifier`) appears stable across recent releases, but algorithm-specific parameters may shift.
- **No CHANGELOG is a red flag** for teams that need to audit what changed between versions. Rely on GitHub Releases page and PR descriptions instead.

## Breaking Change History

No CHANGELOG found. Based on version history (0.8.0 → 0.9.0), the team increments minor versions for new features and patches for fixes — standard semver practice. No evidence of frequent breaking API changes in the core `oneshot` interface.

Minor-version bumps (`0.8 → 0.9`) may include breaking changes in:
- Algorithm-specific modifier parameters
- Recipe YAML schema
- `compressed-tensors` format version compatibility

## Security Posture

- No `SECURITY.md` found — no formal vulnerability disclosure policy
- Apache 2.0 license provides patent grant
- The library does not run as a server (no network surface by default)
- Risk: the library loads arbitrary model weights from HuggingFace Hub; malicious weights are a theoretical supply-chain concern shared by all HF-integrated tooling

## License Risk

**Apache 2.0** — zero license risk for commercial use. Model weights produced by llm-compressor carry their original model licenses (Llama 3 custom license, Mistral Apache 2.0, etc.), not the library's license.

## Dependency Risk

| Key Dependency | Risk |
|----------------|------|
| `transformers>=4.56` | Low — HuggingFace is stable and well-maintained |
| `torch>=2.9` | Low — PyTorch has strong backward compat |
| `compressed-tensors==0.13.0` | Moderate — exact version pinning in release builds suggests tight coupling; format may evolve |
| `auto-round>=0.9.6` | Low-moderate — newer dependency from Intel |
| `accelerate>=1.6` | Low — HuggingFace maintained |

The `compressed-tensors` exact-version pin is the most notable dependency risk: if the format changes significantly, quantized checkpoints may need re-generation.

## Abandonment Signals

None visible:
- Last push: Feb 17, 2026 (yesterday)
- 44 open PRs (too many PRs suggest high activity, not abandonment)
- Active Slack channels (`#sig-quantization`, `#llm-compressor`)
- Frontier-scale model support added in latest release

## Overall Risk Rating

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Abandonment | 🟢 Low | Red Hat-backed, actively used in production |
| Bus factor | 🟡 Medium | Top-3 = 48%, small core team |
| API stability | 🟡 Medium | Pre-1.0, no formal CHANGELOG |
| Security disclosure | 🟡 Medium | No SECURITY.md |
| License | 🟢 Low | Apache 2.0, no copyleft |
| Dependencies | 🟢 Low | Stable HF ecosystem |
