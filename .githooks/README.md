# Git hooks

This repository protects `main` from direct commits and pushes. Enable the
tracked hooks once after cloning:

```sh
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/pre-push
```

The hooks intentionally allow commits and pushes from topic branches. Branch
protection should still be enabled on the remote as the authoritative control.
