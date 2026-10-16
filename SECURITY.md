# Security policy

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report vulnerabilities privately through GitHub Security Advisories:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability**.
3. Describe the issue, the affected version or commit, how to reproduce it, and the impact.

Please include enough detail to reproduce the problem (Android version, device model, steps, proof of concept if you have one). Do not include real passwords, vault files or personal messages.

## What to expect

This is a personal project maintained by one person, so I can't promise a fixed response time. I will:

- acknowledge the report as soon as I can;
- keep you informed while I investigate and fix it;
- credit you in the advisory if you wish, once a fix is available.

Please give a reasonable amount of time for a fix before any public disclosure.

## Scope

In scope: the Sentinel Android app in this repository (Dart and Kotlin code), the vault file format and cryptography, the scam-detection pipeline, and the CI configuration.

Out of scope: vulnerabilities in Android itself, in third-party services (e.g. Have I Been Pwned) or in dependencies (please report those upstream), and attacks that require a rooted or already compromised device. Those are listed as known limitations in [docs/SECURITY_DESIGN.md](docs/SECURITY_DESIGN.md).
