# Signing and Notarization

DockPin can be released in two modes:

- Community build: ad-hoc signed, open-source, and buildable by anyone. macOS Gatekeeper may show a verification warning after download.
- Developer ID build: signed and notarized with an Apple Developer account. This is the mode required to avoid the "Apple could not verify DockPin" warning for most users.

## Required Apple Account

You need an active Apple Developer Program membership.

Create a Developer ID Application certificate, export it as a `.p12`, and create an app-specific password for notarization.

## GitHub Secrets

Configure these repository secrets:

- `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`: base64-encoded `.p12` certificate.
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`: password for the `.p12` certificate.
- `APPLE_KEYCHAIN_PASSWORD`: temporary CI keychain password. Any strong random value is fine.
- `APPLE_ID`: Apple ID email used for notarization.
- `APPLE_TEAM_ID`: Apple Developer Team ID.
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization.
- `CODE_SIGN_IDENTITY`: optional. Defaults to `Developer ID Application`.

Encode the certificate:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

## Release

After secrets are configured, push a version tag:

```sh
git tag -a v0.1.1 -m "DockPin 0.1.1"
git push origin v0.1.1
```

The release workflow will:

1. Import the Developer ID certificate.
2. Build `DockPin.app`.
3. Sign with hardened runtime.
4. Submit to Apple notarization.
5. Staple the notarization ticket.
6. Upload `DockPin.zip` to GitHub Releases.

If the secrets are not configured, the workflow still creates a community build.
