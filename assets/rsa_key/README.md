# RSA Public Key for Yarbo Cloud Authentication

`Connect-YarboCloud` RSA-encrypts your password before sending it to the
Yarbo cloud API. This directory must contain the RSA public key used by the
Yarbo backend for password encryption.

## How to obtain the key

The public key can be extracted from the official Yarbo mobile app APK:

1. Download the latest Yarbo Android APK (e.g., from the Play Store via an
   APK extractor, or from official sources).
2. Unzip the APK and locate the PEM file inside `assets/` or `res/`.
3. Copy the PEM-encoded public key to this file:
   `assets/rsa_key/rsa_public_key.pem`

## Expected format

The file must be a valid PEM-encoded RSA public key:

```
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
...
-----END PUBLIC KEY-----
```

## Using a custom key path

If you store the key elsewhere, pass the path to `Connect-YarboCloud`:

```powershell
Connect-YarboCloud -Email 'user@example.com' `
                   -Password (Read-Host -AsSecureString) `
                   -RsaPublicKeyPath 'C:\path\to\rsa_public_key.pem'
```

## Why this file is not bundled

The RSA public key belongs to Yarbo / Zhejiang Xinghui Intelligent
Technology Co., Ltd. It is not redistributed here to respect intellectual
property. Extract it from the official app.
