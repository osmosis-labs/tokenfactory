#!/bin/bash

source dockernet/config.sh

RED=$(echo -en "\e[31m")
NORMAL=$(echo -en "\e[00m")
GREEN=$(echo -en "\e[32m")

BOB_DENOM="bob-denom1"
ALICE_DENOM="alice-denom"
MINT_AMOUNT=100
BURN_AMOUNT=50
TRANSFER_AMOUNT=50

GETBAL() {
  head -n 1 | grep -o -E '[0-9]+' || "0"
}

GETDENOM() {
  grep -o -E 'factory\/cosmos[0-9a-z]{39}\/.+'
}

GETADMIN() {
  grep -o -E 'cosmos[0-9a-z]{39}'
}

log_failure() {
  printf "${RED}✖ %s${NORMAL}\n" "$@" >&2
}

log_success() {
  printf "${GREEN}✔ %s${NORMAL}\n" "$@" >&2
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3-}"

  if [ "$expected" == "$actual" ]; then
    return 0
  else
    [ "${#msg}" -gt 0 ] && log_failure "$expected == $actual :: $msg" || true
    return 1
  fi
}

assert_contain() {
  local haystack="$1"
  local needle="${2-}"
  local msg="${3-}"

  if [ -z "${needle:+x}" ]; then
    return 0;
  fi

  if [ -z "${haystack##*$needle*}" ]; then
    return 0
  else
    [ "${#msg}" -gt 0 ] && log_failure "$haystack doesn't contain $needle :: $msg" || true
    return 1
  fi
}

######################## TOKENFACTORY MODULE WAS IMPORTED #####################################
PARAMS=$($SIMD_MAIN_CMD query tokenfactory params)

assert_contain "$PARAMS" "denom: $CREATION_FEE_DENOM" "Check denom creation fee denom"
if [ "$?" == 0 ]; then
    log_success "Valid creation fee denom"
else
    log_failure "invalid creation fee denom"
fi

assert_contain "$PARAMS" "amount: \"$CREATION_FEE_AMOUNT\"" "Check creation fee amount"
if [ "$?" == 0 ]; then
    log_success "Valid creation fee amount"
else
    log_failure "invalid creation fee amount"
fi


######################## TEST CREATE DENOM #####################################
# get initial balances
bob_balance_start=$($SIMD_MAIN_CMD  q bank balances $(BOB_ADDRESS) --denom $CREATION_FEE_DENOM   | GETBAL)

# do create denom with bob
$SIMD_MAIN_CMD tx tokenfactory create-denom $BOB_DENOM --from bob -y --gas auto
sleep 10

# get owner denoms to check
DENOM=$($SIMD_MAIN_CMD q tokenfactory denoms-from-creator $(BOB_ADDRESS) | GETDENOM)

assert_eq "$DENOM" "factory/$(BOB_ADDRESS)/$BOB_DENOM" "Get denom created"
if [ "$?" == 0 ]; then
    log_success "Bob created denom successfully "
else
    log_failure "Wrong denom"
fi

# get new balances
bob_balance_end=$($SIMD_MAIN_CMD  q bank balances $(BOB_ADDRESS) --denom $CREATION_FEE_DENOM   | GETBAL)

# get all balance diffs
bob_balance_diff=$(($bob_balance_start - $bob_balance_end))

assert_eq "$bob_balance_diff" "$CREATION_FEE_AMOUNT" "Check denom creation fee"
if [ "$?" == 0 ]; then
    log_success "Denom creation fee has been charged"
else
    log_failure "Denom creation fee has not been charged"
fi


# get denom metadata
ADMIN=$($SIMD_MAIN_CMD q tokenfactory denom-authority-metadata $DENOM | GETADMIN)
assert_eq "$(BOB_ADDRESS)" "$ADMIN" "Check denom admin"
if [ "$?" == 0 ]; then
    log_success "Valid denom's admin"
else
    log_failure "Invalid denom's admin"
fi


######################## TEST MINT & BURN & TRANSFER TOKENS #####################################
# get balance of bob 
bob_balance_start=$($SIMD_MAIN_CMD  q bank balances $(BOB_ADDRESS) --denom $DENOM   | GETBAL)

# mint token 
$SIMD_MAIN_CMD tx tokenfactory mint $MINT_AMOUNT$DENOM --from bob -y --gas auto

sleep 10

# get bob balances after minting
bob_balance_after_minting=$($SIMD_MAIN_CMD  q bank balances $(BOB_ADDRESS) --denom $DENOM   | GETBAL)
bob_balance_mint_diff=$(($bob_balance_after_minting - $bob_balance_start))
assert_eq "$bob_balance_mint_diff" "$MINT_AMOUNT" "Check mint tokens"
if [ "$?" == 0 ]; then
    log_success "Minting successfully"
else
    log_failure "Minting unsuccessfully"
fi

# burn token
$SIMD_MAIN_CMD tx tokenfactory burn $BURN_AMOUNT$DENOM --from bob -y --gas auto

sleep 10

# get bob balances after burning
bob_balance_after_burning=$($SIMD_MAIN_CMD  q bank balances $(BOB_ADDRESS) --denom $DENOM   | GETBAL)
bob_balance_burn_diff=$(($bob_balance_after_minting - $bob_balance_after_burning))
assert_eq "$bob_balance_burn_diff" "$BURN_AMOUNT" "Check burn tokens"
if [ "$?" == 0 ]; then
    log_success "Burning successfully"
else
    log_failure "Burning unsuccessfully"
fi

# transfer to alice
$SIMD_MAIN_CMD tx bank send $(BOB_ADDRESS) $(ALICE_ADDRESS) $TRANSFER_AMOUNT$DENOM --from bob -y --gas auto

sleep 10

# get alice balances
alice_balance=$($SIMD_MAIN_CMD  q bank balances $(ALICE_ADDRESS) --denom $DENOM   | GETBAL)
assert_eq "$alice_balance" "$TRANSFER_AMOUNT" "Check transfer tokens"
if [ "$?" == 0 ]; then
    log_success "Transfering successfully"
else
    log_failure "Transfering unsuccessfully"
fi


######################## TEST CHANGE ADMIN #####################################
$SIMD_MAIN_CMD tx tokenfactory change-admin $DENOM $(ALICE_ADDRESS) --from bob -y --gas auto
sleep 10

# get denom metadata
ADMIN=$($SIMD_MAIN_CMD q tokenfactory denom-authority-metadata $DENOM | GETADMIN)
assert_eq "$(ALICE_ADDRESS)" "$ADMIN" "Check new admin"
if [ "$?" == 0 ]; then
    log_success "Changing admin successfully"
else
    log_failure "Changing admin unsuccessfully"
fi

# From now alice can burn her token
$SIMD_MAIN_CMD tx tokenfactory burn $BURN_AMOUNT$DENOM --from alice -y --gas auto
sleep 10

# get alice balances
alice_balance=$($SIMD_MAIN_CMD  q bank balances $(ALICE_ADDRESS) --denom $DENOM   | GETBAL)
assert_eq "$alice_balance" "0" "Check new admin burn tokens"
if [ "$?" == 0 ]; then
    log_success "New admin burn tokens successfully"
else
    log_failure "New admin burn tokens unsuccessfully"
fi