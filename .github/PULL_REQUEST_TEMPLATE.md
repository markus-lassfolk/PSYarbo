## Summary

<!-- Describe your changes in a few sentences. Link the related issue(s). -->

Closes #<!-- issue number -->

## Type of change

- [ ] 🐛 Bug fix (non-breaking change that fixes an issue)
- [ ] ✨ New feature (non-breaking change that adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to change)
- [ ] 🧹 Refactor / code cleanup (no behaviour change)
- [ ] 📝 Documentation update
- [ ] ⚙️ CI/CD / tooling change

## Changes made

<!-- Bullet-point summary of what changed and why. -->

- 
- 

## Testing

<!-- Describe how you tested this. Include commands you ran. -->

- [ ] Added / updated Pester tests
- [ ] All tests pass locally (`Invoke-Pester ./tests`)
- [ ] Tested manually against Yarbo hardware (if applicable — describe setup)

## Quality checklist

- [ ] **PSScriptAnalyzer**: Zero Error or Warning findings (`Invoke-ScriptAnalyzer ./src -Settings ./PSScriptAnalyzerSettings.psd1 -Severity Error,Warning`)
- [ ] **Tests pass**: `Invoke-Pester ./tests` — all green
- [ ] **Module manifest updated** if version changed
- [ ] **CHANGELOG.md** updated under `[Unreleased]`
- [ ] **Docs updated** (comment-based help, README if needed)
- [ ] **No secrets, credentials, or PII** in code, comments, or commit messages
- [ ] **Follows coding standards** in [CONTRIBUTING.md](../CONTRIBUTING.md)

## Screenshots / output (optional)

<!-- Paste relevant terminal output, before/after if helpful. -->

---

> **Reviewer note**: Branch must be up-to-date with `develop` and all CI checks must pass before merge.
