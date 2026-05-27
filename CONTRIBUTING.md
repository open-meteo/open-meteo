# Contributing to Open-Meteo

Pull requests are welcome. Here's how to make one that won't waste anyone's time.

## Before you start

Open an issue first if you're fixing a bug or adding something non-trivial. Saves you writing code that won't get merged.

Small stuff like typo fixes or one-line bugfixes — just send the PR.

## Making changes

**Keep it simple.** Don't add abstractions nobody asked for. Don't refactor things you're not touching.

**Surgical changes.** Every line you change should trace back to what you're fixing. If you're touching code the maintainer didn't ask about, you better have a good reason.

**Test your changes.** Run the tests before opening a PR. If you broke something, fix it.

## The PR

**Title.** Short. Describes what changed, not why.

```
Fix heavy convective rain classified as moderate rain shower
```

Not:

```
Fix 3 bugs in AQI threshold lookup and weather code mapping
```

If you have multiple unrelated fixes, send separate PRs.

**Description.** Explain the problem and your fix. If it's a bug, include what you saw vs what should have happened. Real examples help.

The maintainer will read your PR and either merge it or ask questions. If he asks something, answer directly. Don't argue unless you're sure you're right — and if he shows you're wrong, just fix it.

## Code style

- Protocol-oriented. Favor protocols over inheritance.
- Async/await everywhere. No callbacks.
- No comments unless the code genuinely can't be made clear on its own.
- Match the style of the file you're editing. If surrounding code uses `for (i, value) in self.enumerated()`, don't rewrite it as `for i in 1..<count`.
- Keep functions short. If a function is doing more than one thing, split it.

## What gets merged

- Bug fixes with real-world impact
- New weather model integrations
- Performance improvements
- Correctness fixes

What doesn't:
- Cosmetic changes (reformatting, renaming for style preferences)
- Changes that fix a problem you can't demonstrate actually happens
- Adding features nobody asked for
