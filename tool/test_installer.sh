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

# Behaves like GitHub for an address whose API allowance is spent. Only the real
# redirect URL gets $1 as its response; an answer that ignored the URL is how a
# fallback pointing at a page that does not exist once passed these tests.
mock_github() {
  _redirect_response="$1"
  curl() {
    case "$*" in
      *api.github.com*)
        printf '{"message":"API rate limit exceeded for 203.0.113.7."}\n' ;;
      *//github.com/neckbeard-io/flax/releases/latest*)
        printf '%b' "$_redirect_response" ;;
      *)
        printf 'HTTP/2 404\r\n\r\n' ;;
    esac
  }
}

# ── Tests ─────────────────────────────────────────────────────────────

echo "install.sh — resolve_latest_version"

# 1. The redirect names the stable release, however spent the API allowance is
(
  FLAX_TEST=1 source "$INSTALLER" 2>/dev/null
  mock_github 'HTTP/2 302\r\nlocation: https://github.com/neckbeard-io/flax/releases/tag/v0.7.0\r\n\r\n'
  got=$(resolve_latest_version 2>/dev/null)
  [ "$got" = "0.7.0" ]
) && _pass "Redirect resolves with the API rate-limited" || _fail "Redirect resolves with the API rate-limited"

# 2. HTTP/1.1 capitalizes the header
(
  FLAX_TEST=1 source "$INSTALLER" 2>/dev/null
  mock_github 'HTTP/1.1 302 Found\r\nLocation: https://github.com/neckbeard-io/flax/releases/tag/v1.0.0\r\n\r\n'
  got=$(resolve_latest_version 2>/dev/null)
  [ "$got" = "1.0.0" ]
) && _pass "Capitalized Location header" || _fail "Capitalized Location header"

# 3. Tag without leading v — strip is a no-op
(
  FLAX_TEST=1 source "$INSTALLER" 2>/dev/null
  mock_github 'HTTP/2 302\r\nlocation: https://github.com/neckbeard-io/flax/releases/tag/0.5.1\r\n\r\n'
  got=$(resolve_latest_version 2>/dev/null)
  [ "$got" = "0.5.1" ]
) && _pass "Tag without leading v" || _fail "Tag without leading v"

# 4. With no stable release GitHub redirects to bare /releases → exits non-zero
(
  FLAX_TEST=1 source "$INSTALLER" 2>/dev/null
  mock_github 'HTTP/2 302\r\nlocation: https://github.com/neckbeard-io/flax/releases\r\n\r\n'
  resolve_latest_version 2>/dev/null
  exit 0  # force failure of outer test if we get here
) && _fail "Bare /releases redirect should be rejected" || _pass "Bare /releases redirect is rejected"

# 5. A tag that is not a version → exits non-zero
(
  FLAX_TEST=1 source "$INSTALLER" 2>/dev/null
  mock_github 'HTTP/2 302\r\nlocation: https://github.com/neckbeard-io/flax/releases/tag/nightly\r\n\r\n'
  resolve_latest_version 2>/dev/null
  exit 0
) && _fail "Non-version tag should be rejected" || _pass "Non-version tag is rejected"

# 6. No response at all, as when offline → exits non-zero
(
  FLAX_TEST=1 source "$INSTALLER" 2>/dev/null
  curl() { return 6; }
  resolve_latest_version 2>/dev/null
  exit 0
) && _fail "Empty response should exit non-zero" || _pass "Empty response exits non-zero"

# 7. An HTML error page → rejected as invalid version
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
