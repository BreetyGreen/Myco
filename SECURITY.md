# Security Policy

## Scope

This project ships a portable `SKILL.md` and a small, pure-standard-library
Python distributor (`scripts/distribute.py`) that copies skill folders into
per-agent directories. It runs locally, has no network calls, and stores no
secrets. The realistic risk surface is small, but reports are still welcome.

## Supported versions

The latest release on the `master` branch is the only supported version.

| Version | Supported |
|---------|-----------|
| latest (`master`) | ✅ |
| older tags | ❌ |

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Instead, use GitHub's private reporting:

1. Go to the **Security** tab of this repository.
2. Click **Report a vulnerability** (Private vulnerability reporting).
3. Describe the issue, affected file(s), and reproduction steps.

If private reporting is unavailable, you may open a minimal issue asking a
maintainer to reach out, without disclosing details publicly.

## What to expect

- An acknowledgement, typically within a few days.
- An assessment of severity and, if valid, a fix in a subsequent release.
- Credit in the release notes if you'd like it.
