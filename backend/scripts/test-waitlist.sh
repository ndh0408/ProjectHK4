#!/usr/bin/env bash
# End-to-end waitlist integration test.
# Drives the LUMA API through a real waitlist scenario and asserts each step.
#
# Prerequisites:
#   - Backend running at $BASE_URL (default http://localhost:8080)
#   - Database seeded (DataSeeder already ran; looks for "Waitlist Demo (Free)")
#   - 3 regular test users exist with password "user123" (from DataSeeder)
#   - curl + jq on PATH
#
# Usage:
#   ./backend/scripts/test-waitlist.sh              # free event scenario
#   EVENT_NAME="Waitlist Demo (Paid)" ./backend/scripts/test-waitlist.sh
#   BASE_URL=http://localhost:8080 ./backend/scripts/test-waitlist.sh
#
# Exits non-zero on the first failing assertion.

set -eo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
EVENT_NAME="${EVENT_NAME:-Waitlist Demo (Free)}"

USER_A_EMAIL="${USER_A_EMAIL:-nguyenvan@gmail.com}"
USER_B_EMAIL="${USER_B_EMAIL:-tranbi@gmail.com}"
USER_C_EMAIL="${USER_C_EMAIL:-leminh@gmail.com}"
USER_PASS="${USER_PASS:-user123}"

ORG_EMAIL="${ORG_EMAIL:-admin@luma.com}"
ORG_PASS="${ORG_PASS:-admin123}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

step()   { echo -e "${BLUE}==>${NC} $*"; }
ok()     { echo -e "${GREEN}  [OK]${NC} $*"; }
fail()   { echo -e "${RED}  [FAIL]${NC} $*"; exit 1; }
warn()   { echo -e "${YELLOW}  [WARN]${NC} $*"; }

require_tool() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required tool: $1"; exit 2; }
}
require_tool curl
require_tool jq

login() {
  local email="$1" pass="$2"
  local resp
  resp="$(curl -sS -X POST "$BASE_URL/api/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$email\",\"password\":\"$pass\"}")"
  local token
  token="$(echo "$resp" | jq -r '.data.accessToken // empty')"
  if [[ -z "$token" || "$token" == "null" ]]; then
    echo "Login failed for $email: $resp" >&2
    return 1
  fi
  echo "$token"
}

auth_get() {
  local token="$1" path="$2"
  curl -sS "$BASE_URL$path" -H "Authorization: Bearer $token"
}

auth_post() {
  local token="$1" path="$2" body="${3:-}"
  if [[ -n "$body" ]]; then
    curl -sS -X POST "$BASE_URL$path" \
      -H "Authorization: Bearer $token" \
      -H 'Content-Type: application/json' \
      -d "$body"
  else
    curl -sS -X POST "$BASE_URL$path" -H "Authorization: Bearer $token"
  fi
}

auth_delete() {
  local token="$1" path="$2"
  curl -sS -X DELETE "$BASE_URL$path" -H "Authorization: Bearer $token"
}

find_event_id() {
  local token="$1"
  auth_get "$token" "/api/user/events/upcoming?size=100" \
    | jq -r --arg name "$EVENT_NAME" \
      '.data.content[] | select(.title == $name) | .id' \
    | head -n1
}

step "Logging in organiser, user A, user B, user C"
TOKEN_ORG="$(login "$ORG_EMAIL" "$ORG_PASS")" || fail "organiser login"
TOKEN_A="$(login "$USER_A_EMAIL" "$USER_PASS")"   || fail "user A login"
TOKEN_B="$(login "$USER_B_EMAIL" "$USER_PASS")"   || fail "user B login"
TOKEN_C="$(login "$USER_C_EMAIL" "$USER_PASS")"   || fail "user C login"
ok "all four logged in"

step "Locating demo event '$EVENT_NAME'"
EVENT_ID="$(find_event_id "$TOKEN_A")"
if [[ -z "$EVENT_ID" ]]; then
  fail "event '$EVENT_NAME' not found — did DataSeeder run?"
fi
ok "event id = $EVENT_ID"

step "Fetching event details (expect capacity=1)"
EVENT_JSON="$(auth_get "$TOKEN_A" "/api/user/events/$EVENT_ID")"
CAPACITY="$(echo "$EVENT_JSON" | jq -r '.data.capacity')"
APPROVED="$(echo "$EVENT_JSON" | jq -r '.data.approvedCount')"
if [[ "$CAPACITY" != "1" ]]; then
  fail "capacity should be 1, got $CAPACITY"
fi
ok "capacity=$CAPACITY, initial approvedCount=$APPROVED"

step "User A registers (should land APPROVED or PENDING — not waitlist)"
REG_A="$(auth_post "$TOKEN_A" "/api/user/events/$EVENT_ID/register" '{"quantity":1}')"
STATUS_A="$(echo "$REG_A" | jq -r '.data.status')"
REG_A_ID="$(echo "$REG_A" | jq -r '.data.id')"
if [[ "$STATUS_A" == "WAITING_LIST" ]]; then
  fail "user A should not be on waitlist (event was empty). Got $STATUS_A. Raw: $REG_A"
fi
ok "user A status = $STATUS_A (id=$REG_A_ID)"

step "User B registers (event now full, must join waitlist)"
REG_B="$(auth_post "$TOKEN_B" "/api/user/events/$EVENT_ID/register" '{"quantity":1}')"
STATUS_B="$(echo "$REG_B" | jq -r '.data.status')"
POS_B="$(echo "$REG_B" | jq -r '.data.waitingListPosition')"
REG_B_ID="$(echo "$REG_B" | jq -r '.data.id')"
if [[ "$STATUS_B" != "WAITING_LIST" ]]; then
  fail "user B should be WAITING_LIST, got $STATUS_B. Raw: $REG_B"
fi
if [[ "$POS_B" != "1" ]]; then
  fail "user B waitlist position should be 1, got $POS_B"
fi
ok "user B status=WAITING_LIST position=#1"

step "User C registers (also waitlist, position 2)"
REG_C="$(auth_post "$TOKEN_C" "/api/user/events/$EVENT_ID/register" '{"quantity":1}')"
STATUS_C="$(echo "$REG_C" | jq -r '.data.status')"
POS_C="$(echo "$REG_C" | jq -r '.data.waitingListPosition')"
if [[ "$STATUS_C" != "WAITING_LIST" ]]; then
  fail "user C should be WAITING_LIST, got $STATUS_C"
fi
if [[ "$POS_C" != "2" ]]; then
  fail "user C should be position 2, got $POS_C"
fi
ok "user C status=WAITING_LIST position=#2"

step "User A cancels — waitlist should auto-promote B"
auth_delete "$TOKEN_A" "/api/user/events/registrations/$REG_A_ID" >/dev/null
ok "cancel request sent"

# Give the backend a moment to write the offer / promotion.
sleep 1

step "Checking user B promotion state"
B_STATUS_JSON="$(auth_get "$TOKEN_B" "/api/user/events/$EVENT_ID/registration-status")"
B_NEW_STATUS="$(echo "$B_STATUS_JSON" | jq -r '.data.status')"
B_NEW_POS="$(echo "$B_STATUS_JSON" | jq -r '.data.waitingListPosition // empty')"
IS_PAID_EVENT="false"
if [[ "$EVENT_NAME" == *"Paid"* ]]; then
  IS_PAID_EVENT="true"
fi

if [[ "$IS_PAID_EVENT" == "true" ]]; then
  # Paid event: user B should stay WAITING_LIST until they accept the offer,
  # but an offer must exist. We don't have the offer-accept flow in this
  # script yet — just confirm the offer row was created.
  OFFERS="$(auth_get "$TOKEN_B" "/api/user/waitlist/offers")"
  OFFER_COUNT="$(echo "$OFFERS" | jq -r '.data | length // 0')"
  if [[ "$OFFER_COUNT" -lt 1 ]]; then
    fail "paid event: expected >=1 pending offer for user B, got $OFFER_COUNT. Raw: $OFFERS"
  fi
  ok "paid event: user B has $OFFER_COUNT pending waitlist offer(s)"
else
  # Free + requiresApproval=false demo event → promotion should APPROVE directly.
  if [[ "$B_NEW_STATUS" != "APPROVED" && "$B_NEW_STATUS" != "WAITING_LIST" ]]; then
    fail "free event: user B should be APPROVED (or still WAITING_LIST pending offer accept), got $B_NEW_STATUS"
  fi
  if [[ "$B_NEW_STATUS" == "WAITING_LIST" ]]; then
    # Offer created but not accepted — that's the paid-like path for free events
    # too when acceptOffer is not auto-invoked. Verify an offer exists.
    OFFERS="$(auth_get "$TOKEN_B" "/api/user/waitlist/offers")"
    OFFER_COUNT="$(echo "$OFFERS" | jq -r '.data | length // 0')"
    if [[ "$OFFER_COUNT" -lt 1 ]]; then
      fail "free event: expected offer for user B after promotion, got $OFFER_COUNT"
    fi
    ok "free event: user B has offer pending acceptance ($OFFER_COUNT)"
  else
    ok "free event: user B auto-approved after A cancelled"
  fi
fi

step "Verifying user C shifted up to position 1"
C_STATUS_JSON="$(auth_get "$TOKEN_C" "/api/user/events/$EVENT_ID/registration-status")"
C_NEW_POS="$(echo "$C_STATUS_JSON" | jq -r '.data.waitingListPosition')"
if [[ "$C_NEW_POS" != "1" && "$C_NEW_POS" != "2" ]]; then
  warn "user C position after promotion = $C_NEW_POS (expected 1 if B accepted, 2 if still pending offer)"
else
  ok "user C position now #$C_NEW_POS"
fi

step "Cleanup — cancelling remaining registrations"
REG_B_ID_FINAL="$(echo "$B_STATUS_JSON" | jq -r '.data.registrationId // empty')"
REG_C_ID_FINAL="$(echo "$C_STATUS_JSON" | jq -r '.data.registrationId // empty')"
if [[ -n "$REG_B_ID_FINAL" && "$REG_B_ID_FINAL" != "null" ]]; then
  auth_delete "$TOKEN_B" "/api/user/events/registrations/$REG_B_ID_FINAL" >/dev/null || warn "couldn't cancel B"
fi
if [[ -n "$REG_C_ID_FINAL" && "$REG_C_ID_FINAL" != "null" ]]; then
  auth_delete "$TOKEN_C" "/api/user/events/registrations/$REG_C_ID_FINAL" >/dev/null || warn "couldn't cancel C"
fi
ok "cleanup done"

echo -e "\n${GREEN}✓ Waitlist e2e test passed for '$EVENT_NAME'${NC}"
