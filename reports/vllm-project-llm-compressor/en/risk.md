# Risk Assessment — LLM Compressor

> **Source**: https://github.com/vllm-project/llm-compressor | **Analyzed**: 2026-02-18

## Overall Risk: 🟡 Medium (Manageable)

The project is actively maintained with strong corporate backing, but three factors merit
attention: pre-v1 API instability, absence of a formal security disclosure process, and
tight coupling to the compressed-tensors format.

---

## Bus Factor

| Signal | Value | Risk |
|--------|-------|------|
| Top 1 contributor share | 15% | 🟢 Low |
| Top 3 contributor share | 41% | 🟢 Healthy |
| Active maintainers | 6 (named in .MAINTAINERS) | 🟢 Good |
| Contributors from same org | All Red Hat AI / vLLM Project | 🟠 Correlated — layoffs at Red Hat/IBM could affect the whole team |

**Assessment**: Bus factor is individually healthy (no single point of failure) but
organizationally correlated. All 6 maintainers are affiliated with Red Hat AI or the
vLLM Project. An IBM/Red Hat strategic pivot away from this area would be the highest
realistic bus factor risk. Given IBM's deep commitment to enterprise AI, this is a
low-probability event.

---

## Security Posture

| Check | Status |
|-------|--------|
| `SECURITY.md` present | ❌ Not found |
| CVE history | Not researched (no NVD hits expected for a new library) |
| Supply chain risk | Medium — installs torch, transformers, accelerate (large attack surface via dependencies) |
| Dependency audit | No automated `pip-audit` or `safety` observed in CI workflows |
| Third-party security audit | No evidence of one |

**Assessment**: The absence of `SECURITY.md` means there is no documented vulnerability
disclosure process. For an ML tooling library, the direct security risk is low (no
network services, no auth), but the dependency chain (PyTorch, Transformers) is large and
could surface CVEs in transitive dependencies. Teams should run `pip-audit` as part of
their own CI pipelines.

---

## Breaking Change Risk

| Signal | Assessment |
|--------|------------|
| Current version | v0.9.x — **pre-v1** |
| CHANGELOG | Not present — no formal change log |
| Semver discipline | Minor versions (0.7 → 0.8 → 0.9) have introduced new APIs and deprecations |
| Migration guides | Not found as a dedicated doc; README "What's New" section covers highlights |
| API surface stability | `oneshot()` entry point is stable; modifier config schemas evolve per minor version |

**Assessment**: 🟡 **Medium breaking-change risk.** The library is explicitly pre-1.0,
which under semver means no API stability guarantee. In practice:
- The `oneshot()` / `model_free_ptq()` entry points are stable and evolve conservatively.
- Modifier configuration schemas (YAML recipes) and internal modifier APIs change more
  frequently.
- The `dispatch_for_generation` → `dispatch_model` deprecation (Feb 2026) shows that
  convenience APIs do get renamed between minor versions with deprecation warnings.

**Mitigation**: Pin minor version in production (`llmcompressor~=0.9.0`). Test on upgrade.

---

## Abandonment Signals

| Check | Status |
|-------|--------|
| Last commit older than 6 months? | ❌ — pushed **today** (2026-02-18) |
| Open issues unanswered > 3 months? | Unlikely — recent issues closed same-day |
| PR backlog > 50 unreviewed? | 45 open PRs — borderline, but actively worked |
| Maintainer stepping back publicly? | No signal |
| Repo archived? | ❌ — actively developed |
| No release in 12+ months? | ❌ — 8 releases in last 8 months |

**Assessment**: 🟢 **No abandonment risk.** The project is in its most active development
phase to date. Red Hat AI's commercial incentives ensure continued investment.

---

## License Risk

| Aspect | Status |
|--------|--------|
| License | Apache-2.0 |
| Internal use | 🟢 No restrictions |
| SaaS/cloud product | 🟢 No restrictions |
| Patent clause | Apache-2.0 includes patent grant — protects users |
| Contributor License Agreement | Not observed (standard for Apache-licensed projects) |

**Assessment**: 🟢 **Zero license risk.** Apache-2.0 is the most enterprise-friendly open
source license and is fully compatible with commercial use, SaaS products, and proprietary
codebases.

---

## Ecosystem Coupling Risk

A risk specific to LLM Compressor that other frameworks do not share:

- **compressed-tensors format**: The output format is a vLLM Project library
  (`compressed-tensors==0.13.0`, pinned tightly). If vLLM moves away from this format,
  LLM Compressor would need to be updated. This is unlikely given Red Hat AI controls both
  projects.
- **Transformers compatibility**: The `transformers>=4.56.1,<=4.57.6` pin (both min and max)
  is unusually tight. The README shows an open issue about incompatibility with
  `transformers 4.57.3` — indicating fast-moving dependency risk. Teams should expect to
  stay within supported Transformers versions.
- **Python ≥ 3.10 required**: Not a concern for new projects, but teams on Python 3.9 need
  to upgrade.
- **Linux-only**: `setup.py` classifiers show `Operating System :: POSIX :: Linux`. macOS
  and Windows are not officially supported.

---

## Risk Summary

| Risk Category | Level | Notes |
|---------------|-------|-------|
| Bus factor | 🟢 Low | 6 maintainers; top 3 = 41% — healthy |
| Security disclosure | 🟡 Medium | No SECURITY.md; dependency chain is large |
| Breaking changes | 🟡 Medium | Pre-v1; pin minor version in production |
| Abandonment | 🟢 Very Low | Pushed today; Red Hat AI backing |
| License | 🟢 None | Apache-2.0, fully permissive |
| Ecosystem coupling | 🟡 Medium | Transformers version pins are tight; Linux-only |
