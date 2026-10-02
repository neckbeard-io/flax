# Releasing flax

Maintainer reference for release channels, the release workflow, and what
testers see. The everyday rules — branch from `dev`, write the changelog line
with the change — are in [AGENTS.md](../AGENTS.md#branching-and-releases).

## Channels

- **`main` → Stable.** Tags `vX.Y.Z` (e.g. `v0.5.6`), published as standard
  GitHub Releases. The default update channel.
- **`dev` → Dev.** Tags `vX.Y.Z-dev.N` (e.g. `v0.5.7-dev.45`), published with
  `--prerelease`. Served to users who opt into the Dev channel in Settings.

The self-updater follows SemVer 2.0 ordering:
`v0.5.5 < v0.5.6-dev.1 < v0.5.6-dev.2 < v0.5.6`. Stable subscribers ignore
`-dev.*` builds; Dev subscribers see every pre-release and are promoted to the
final `vX.Y.Z` when it lands on `main`.

## What publishes a release

`.github/workflows/release.yml` runs on every push to `dev` and `main`:

- **Push to `dev`** (a merged PR): calculates the next `vX.Y.Z-dev.N`, builds
  every platform, and publishes a pre-release. Its notes are the lines added to
  `## Unreleased` since the previous tag. With no new changelog lines it falls
  back to commit subjects, which is exactly the kind of note the changelog rules
  exist to prevent — so every code change carries its changelog line.
- **Push to `main`** (the promotion merge): reads the closed `## vX.Y.Z — <date>`
  header from `CHANGELOG.md` and publishes the stable release.
- **Docs-only pushes publish nothing.** Changes confined to Markdown, `docs/`
  and `.github/` are in the push trigger's `paths-ignore`.

Runs share `concurrency: release-<ref>` with `cancel-in-progress`, so when PRs
merge in quick succession only the newest tip is built.

Note that pushes to `dev` do not run CI (`ci.yml` covers pull requests and
`main`). The pull request is the only place the checks run, which is why work
lands on `dev` through a PR and never by pushing to it directly.

## Promoting `dev` to `main`

1. When a batch of dev pre-releases has been validated, open a PR from `dev` to
   `main`.
2. In that PR, close off the changelog: rename `## Unreleased` to
   `## vX.Y.Z — <YYYY-MM-DD>` and start a fresh `## Unreleased` above it.
3. Merging it publishes `vX.Y.Z` to the Stable channel.

## Manual runs (`workflow_dispatch`)

```bash
# Stable release from main
gh workflow run release.yml -f version=0.5.7 -f channel=stable --ref main -f macos=true -f windows=true -f linux=true -f android=true

# Dev pre-release from dev
gh workflow run release.yml -f version=0.5.7-dev.2 -f channel=dev --ref dev -f macos=true -f windows=true -f linux=true -f android=true

# Watch the run
gh run watch $(gh run list --workflow=release.yml -L1 --json databaseId --jq '.[0].databaseId')
```

For a manual stable run, close off the changelog **first**, in its own commit
on `main`: the workflow tags whatever `main` points at, so a changelog landed
afterwards is not in the release it describes.

The `version` input is the whole version story — it becomes the build name, the
tag (`v<version>`) and the release title, and the workflow creates the tag
itself. The total commit count (`git rev-list --count HEAD`) is the build number
on every platform, in CI and locally. **Never bump `version:` in
`pubspec.yaml`**; every build path overrides it with `--build-name` /
`--build-number`. Re-running a version uploads to the existing release
(`--clobber`) rather than failing.

## The release body is the changelog — enforced

`release.yml` extracts the version's section from `CHANGELOG.md` and publishes
it as the release body, followed by a link to the README install instructions.
**If the section is missing or empty the run fails**, deliberately and before
anything is published. Do not work around it by editing the workflow — write the
changelog entry, which should have been written with the change anyway.

This is enforced because it silently failed for a long time: every release up to
and including v0.2.3 shipped with the install instructions as its *entire* body,
because the workflow never read `CHANGELOG.md`. Re-runs refresh an existing
release's body rather than keeping whatever it was created with.

## Local builds

macOS (and Android) can be built locally, ~90 s on Apple Silicon:

```bash
tool/release.sh --mac --version 0.4.1   # just the .dmg
tool/release.sh --version 0.4.1         # macOS .dmg + Android .apk, into dist/
gh release upload v0.4.1 dist/flax-0.4.1-macos-universal.dmg
```

**Always pass `--version` when cutting a release.** Without it the script takes
the version from the latest **local** `v*` tag, while the workflow creates the
tag on the runner — so a local build during a release names itself after the
*previous* version and silently overwrites that .dmg in `dist/`. Either pass
`--version`, or `git fetch --tags` after the workflow has created the tag.

Windows cannot be cross-compiled from macOS, so it exists only on the runner —
`tool/release.sh` deliberately has no Windows path.

## Signing, and what testers have to do about it

None of the builds are signed with a real certificate, so each OS pushes back on
first launch. This is expected; don't debug it as breakage.

- **macOS** — ad-hoc signed (`CODE_SIGN_IDENTITY = "-"`); the binary is
  universal (x86_64 + arm64), so one .dmg serves Apple Silicon and Intel. On
  another Mac, macOS 15+ reports the app as *damaged*; the fix is one command
  after installing: `xattr -dr com.apple.quarantine /Applications/flax.app`.
  A clean double-click install later needs the Apple Developer Program, a
  Developer ID Application cert, Hardened Runtime, then `notarytool submit
  --wait` and `stapler staple` on the .dmg. Only the packaging step changes.
- **Windows** — unsigned; SmartScreen warns, *More info* → *Run anyway*. The
  installer (`flax-<version>-windows-x64-setup.exe`) registers flax in the Start
  menu and handles runtime dependencies; or extract the portable `.zip` whole.
- **Android** — signed with a shared *test* keystore so builds upgrade in place.
  `android/key.properties` and `android/flax-test.jks` are gitignored; CI
  rebuilds them from the `FLAX_KEYSTORE_BASE64` and `FLAX_KEYSTORE_PASSWORD`
  secrets. Without `key.properties`, Gradle silently falls back to the
  per-machine debug keystore, and those APKs cannot be installed over a real
  test build. `tool/release.sh` refuses to build rather than ship one.

Android also needs `INTERNET` declared in
`android/app/src/main/AndroidManifest.xml`. Debug builds get it injected and
release builds do not, so removing it breaks only release APKs — every server
request fails while everything looks fine in development.
