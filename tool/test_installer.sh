#!/usr/bin/env bash
# tool/test_installer.sh — unit tests for install.sh's version-detection logic.
#
# Run: bash tool/test_installer.sh
#
# No external dependencies. Each test overrides `curl` to return a controlled
# payload, sources install.sh (guarded by FLAX_TEST=1), and asserts the result.
# Exit code: 0 = all pass, 1 = one or more failures.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/install.sh"

# ── Minimal test harness ──────────────────────────────────────────────
# Counters live in temp files so subshells can update them.

_tmpdir=$(mktemp -d)
echo 0 > "$_tmpdir/pass"
echo 0 > "$_tmpdir/fail"
trap 'rm -rf "$_tmpdir"' EXIT

_pass() {
  echo "  ✓ $1"
  echo $(( $(cat "$_tmpdir/pass") + 1 )) > "$_tmpdir/pass"
}
_fail() {
  echo "  ✗ $1"
  echo $(( $(cat "$_tmpdir/fail") + 1 )) > "$_tmpdir/fail"
}

# ── Tests ─────────────────────────────────────────────────────────────

echo "install.sh — resolve_latest_version"

# 1. API returns a pre-release tag (the normal flax case)
(
  FLAX_TEST=1 source "$INSTALLER" 2>/dev/null
  curl() { echo '[{"tag_name":"v0.5.1","prerelease":true}]'; }
  got=$(resolve_latest_version 2>/dev/null)
  [ "$got" = "0.5.1" ]
) && _pass "API returns pre-release tag" || _fail "API returns pre-release tag"

# 2. API returns a stable (non-pre-release) tag
(
  FLAX_TEST=1 source "$INSTALLER" 2>/dev/null
  curl() { echo '[{"tag_name":"v1.0.0","prerelease":false}]'; }
  got=$(resolve_latest_version 2>/dev/null)
  [ "$got" = "1.0.0" ]
) && _pass "API returns stable tag" || _fail "API returns stable tag"

# 3. API returns tag without leading v — strip is a no-op
(
  FLAX_TEST=1 source "$INSTALLER" 2>/dev/null
  curl() { echo '[{"tag_name":"0.5.1","prerelease":true}]'; }
  got=$(resolve_latest_version 2>/dev/null)
  [ "$got" = "0.5.1" ]
) && _pass "API tag without leading v" || _fail "API tag without leading v"

# 4. API returns empty array → fallback to redirect Location header with /tag/
#    Mock differentiates API vs HEAD calls by presence of "api.github.com" in args.
(
  FLAX_TEST=1 source "$INSTALLER" 2>/dev/null
  curl() {
    case "$*" in
      *api.github.com*) echo '[]' ;;
      *) printf 'HTTP/1.1 302 Found\r\nlocation: https://github.com/neckbeard-io/flax/releases/tag/v0.4.8\r\n\r\n' ;;
    esac
  }
  got=$(resolve_latest_version 2>/dev/null)
  [ "$got" = "0.4.8" ]
) && _pass "Empty API falls back to redirect" || _fail "Empty API falls back to redirect"

# 5. Redirect Location has no /tag/ path (the pre-fix bug) → rejected, exits non-zero
(
  FLAX_TEST=1 source "$INSTALLER" 2>/dev/null
  curl() {
    case "$*" in
      *api.github.com*) echo '[]' ;;
      *) printf 'HTTP/1.1 302 Found\r\nlocation: https://github.com/neckbeard-io/flax/releases\r\n\r\n' ;;
    esac
  }
  resolve_latest_version 2>/dev/null
  exit 0  # force failure of outer test if we get here
) && _fail "Bare /releases redirect should be rejected" || _pass "Bare /releases redirect is rejected"

# 6. Both API and redirect return nothing → exits non-zero
(
  FLAX_TEST=1 source "$INSTALLER" 2>/dev/null
  curl() { echo ''; }
  resolve_latest_version 2>/dev/null
  exit 0
) && _fail "Empty response should exit non-zero" || _pass "Empty response exits non-zero"

# 7. API returns HTML error page → rejected as invalid version
(
  FLAX_TEST=1 source "$INSTALLER" 2>/dev/null
  curl() { echo '<html><body>Rate limited</body></html>'; }
  resolve_latest_version 2>/dev/null
  exit 0
) && _fail "HTML response should be rejected" || _pass "HTML response is rejected"

# ── Summary ───────────────────────────────────────────────────────────

PASS=$(cat "$_tmpdir/pass")
FAIL=$(cat "$_tmpdir/fail")

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
