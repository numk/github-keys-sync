# github-keys-sync

Sync GitHub public SSH keys (`https://github.com/<user>.keys`) into `~/.ssh/authorized_keys`.

Keys live in a managed block (`# BEGIN/END github-keys-sync:<user>`); each run only rewrites that block, so hand-added keys are never touched. Duplicates (within GitHub's list, or already present manually) are skipped. Failed/empty fetches leave the file untouched; a `.bak` is kept.

## One-liner (always latest)

```
curl -fsSL https://raw.githubusercontent.com/numk/github-keys-sync/main/sync-keys.sh | bash -s -- numk
```

Multiple users: `... | bash -s -- alice bob`.

## Platforms
- Linux / macOS: works as is.
- Windows: run in Git Bash or WSL. For Administrator accounts OpenSSH reads `C:\ProgramData\ssh\administrators_authorized_keys`; use `AUTHORIZED_KEYS=/c/ProgramData/ssh/administrators_authorized_keys`.
