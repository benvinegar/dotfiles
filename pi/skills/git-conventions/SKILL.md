---
name: git-conventions
description: Git commit conventions. Always applied when making commits on behalf of the user.
---

# Git Conventions

When making git commits on behalf of the user, always add a co-author trailer:

```
Co-authored-by: pi <pi@anthropic.com>
```

Example:

```bash
git commit -m "fix: resolve edge case in parser

Co-authored-by: pi <pi@anthropic.com>"
```
