# v0.5 release checklist

[Back to README](../README.md)

This is a manual release gate, not permission or automation to tag or publish. The project license is MIT; see [LICENSE](../LICENSE).

## Validate the candidate

- [ ] Review the candidate PR; keep main clean and require Windows CI to pass on the intended merge candidate.
- [ ] Confirm module, collector, and comparison implementation versions are `0.5.0`; inventory schema is `0.2`, historical inventory support is `0.1`, comparison schema is `0.1`, and minimum PowerShell is `7.0`.
- [ ] In PowerShell 7 on Windows, install the suite's pinned test dependency when needed: `Install-Module Pester -RequiredVersion 3.4.0 -Repository PSGallery -Scope CurrentUser -Force -SkipPublisherCheck`. This is development setup, never product behavior.
- [ ] From the source checkout, run `./scripts/Invoke-Tests.ps1`. It pins Pester, rejects failed/empty suites, and emits a safe summary instead of real inventories or failure-value dumps.
- [ ] Run `./scripts/Test-Release.ps1`. It parses production PowerShell, validates the manifest, invokes `./scripts/Build-ModulePackage.ps1` from unrelated cwd, extracts the ZIP to temporary storage, checks import/inspection/export/version/privacy contracts, and verifies installed-by-name discovery in a fresh child process. Only that child receives a temporary PSModulePath prefix. Where Windows PowerShell 5.1 exists, its acceptance script uses a process-scoped execution-policy bypass (no persistent policy change) to verify import fails on the manifest runtime requirement.
- [ ] Confirm all documentation links and packaged help pass the documentation tests. Review [privacy boundaries](privacy.md); the raw tool-probe exclusion is not universal redaction of health text.
- [ ] Review the production mutation scan: no PATH, execution policy, Git/auth, package, Python/npm, Windows feature, WSL, or Hyper-V mutations. Requested reports/logs are allowed output. Review external probe arguments, not just cmdlet names.
- [ ] Confirm deterministic optional-tool/non-elevated tests pass, with selected-but-broken runtimes still distinguished from absent optional capabilities.
- [ ] Run `git diff --check` and `git status --short`; investigate unexpected changes. The build regenerates ignored `dist`, not tracked source files.
- [ ] Confirm Windows Actions is green after commit/push. Local success alone does not establish hosted-runner success.
- [ ] Review the Actions artifact `DevRigInspector-0.5.0`, containing `DevRigInspector-0.5.0.zip`. It is a CI artifact, not a GitHub Release or Gallery publication.

## Manual release decisions

- [x] Resolve and document licensing; MIT selected by the project owner and recorded in LICENSE.
- [ ] Approve the PR and merge through the normal repository process.
- [ ] Verify clean main and green CI on the merged commit; review the validated package and release notes.
- [ ] Explicitly approve the tag and GitHub Release before creating either. No script/workflow here creates a tag, release, or PowerShell Gallery publication.

## CI and local reproducibility

The source workflow is `.github/workflows/windows.yml`: pull requests, pushes to main, and manual dispatch use `windows-2022` with `pwsh`. It calls the same scripts used locally. Pester 3.4.0 is pinned because this suite uses its legacy assertion and mock/scoping behavior; upgrading Pester requires a deliberate suite validation, not reliance on whichever version a runner happens to contain. [The pinned package](https://www.powershellgallery.com/packages/Pester/3.4.0) has no dependencies.

Real inspections depend on host PATH and optional tools and may query GitHub authentication state, but tests do not assert the runner's tool versions or an authenticated account. Semantic fixtures cover absence, failure, and unavailable evidence. Process-runner tests deliberately launch PowerShell and time out a sleeping child. No runner tools are removed and no feature or authentication configuration is changed to manufacture test conditions.

CI installs only Pester as a test dependency in CurrentUser scope. Product inspection does not install anything. CI logs show versions, test counts, parser/manifest results, package paths, and public exports, not full inventories, arbitrary environment variables, or authentication transcripts. Confirm that the candidate PR's Windows run is green for the exact commit under review.
