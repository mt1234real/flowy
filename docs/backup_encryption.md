# Backup encryption contract

New backups use envelope V2, independently of inner capsule version 4 and SQLite schema version. V1 is decrypt-only. No existing Drive files are rewritten.

## V2

The fixed 87-byte header is `FLOWYENC` (8 bytes), version 2, algorithm 1 (AES-256-GCM), KDF 1 (HKDF-SHA256), generation ID (SHA-256 of the master secret, 32 bytes), random salt (32 bytes), and random nonce (12 bytes). Ciphertext and the 16-byte GCM tag follow. The full header plus the domain-separated account ID is authenticated as AAD. HKDF uses the independent random 32-byte master secret and public salt, with info `flowy-backup-v2`.

Primitives come from encrypt/PointyCastle. PointyCastle 3.9.1 was already installed transitively; it is now a direct dependency for HKDF. Random values use encrypt's CSPRNG-backed APIs. No PIN, email, fixed pepper or device identifier supplies V2 key entropy.

## Portable keys and recovery

Immutable JSON key records live separately in Google Drive `appDataFolder`, named `flowy_backup_key_v1_<generation>.json`. They contain record version 1, generation ID and the base64 master secret. They never enter the encrypted capsule, backup manifests or ordinary backup metadata. Drive OAuth app-data access is required to retrieve them; possession of a backup file ID is insufficient. Reference: https://developers.google.com/workspace/drive/api/guides/appdata

The account namespace and generation identify local FlutterSecureStorage cache entries. A versioned active-generation cache also holds the account namespace, generation, immutable Drive file locator and encoded key record. Ordinary backups read this secure cache and fetch/validate the exact remote record before use: one key GET, independent of backup history. Local key material alone is never sufficient. Missing/corrupt/mismatched current remote material fails closed without switching generations or creating a replacement. Restore still resolves the exact generation required by its envelope; it does not change the active write generation. Logout removes local cached keys, preserving all remote records and backups.

Full discovery/historical integrity runs when the active cache is absent, invalid or lacks a usable locator, including upgrades from generation-only caches and first initialization. It enumerates all remote key records and backup references before creating a random key. Known V2 metadata identifies referenced generations; files without it are inspected by their envelope header. Missing referenced generations prohibit new key creation. Malformed/unsupported records also stop the operation. No failed network request is interpreted as an empty account. Ordinary backups verify their current generation only; they no longer preflight every historical generation on every write. Loss of a non-current historical generation is detected during full discovery or exact-generation restore, not by unrelated steady-state writes.

Concurrent callers in one isolate share initialization. Drive has no unique-name create primitive across devices, so concurrent first initialization can leave multiple immutable generations. Every created record is read back and confirmed before use; all generations remain available, and each backup authenticates its generation ID. Discovery selects the lexically first available generation, then ordinary writers retain that verified active generation. No loser is overwritten or deleted. This favors recoverability over claiming a distributed singleton guarantee.

If a key record is deleted, backups using it cannot be restored through the app until the original portable record is recovered. The app refuses to substitute a new key, including when it still holds a local cached copy. If both all key records and all associated backups have been removed, the remote account is indistinguishable from first-time initialization.

The authenticated Drive client and account ID are captured together for each backup/restore operation. Later UI account switching cannot change the cryptographic account binding for that operation.

## Compatibility and failures

V1 has no magic/header: it is a 16-byte IV followed by AES-GCM ciphertext/tag. Its HMAC-SHA256 account-ID/fixed-pepper derivation exists only in the compatibility decrypt path. Non-magic files must authenticate as V1 before their plaintext is accepted. A recognized V2 envelope never falls back to V1 after an error. A Drive file marked V2 is also rejected if replaced with an unmarked V1 payload. Unknown versions/algorithms/KDFs fail explicitly. Authentication precedes ZIP extraction, preferences, security configuration and live database installation. Failed Cloud downloads/decryptions remove their isolated restore directory.

## Threat model and verification limits

V2 protects a copied backup against an attacker who knows the account ID and all public source/constants but lacks the independent master secret. It does not protect against authenticated access to the victim's Drive appData, malicious code with app credentials, or a compromised unlocked device. This is not a claim of end-to-end protection against Google-account compromise.

Tests cover the production Drive adapter through an in-memory API boundary, crypto tampering, missing/corrupt keys, competing generations, V1 compatibility, V1/V2 full restore and legacy schema normalization, and backup revision acknowledgement. Real Google Drive cross-device/OEM WorkManager validation remains pending.
