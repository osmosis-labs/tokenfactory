load "bats/bats-support/load.bash"
load "bats/bats-assert/load.bash"
source dockernet/config.sh

GETBAL() {
  head -n 1 | grep -o -E '[0-9]+' || "0"
}

GETDENOM() {
  grep -o -E 'factory\/cosmos[0-9a-z]{39}\/.+'
}

GETADMIN() {
  grep -o -E 'cosmos[0-9a-z]{39}'
}

BOB_DENOM="bob-denom"
ALICE_DENOM="alice-denom"
MINT_AMOUNT=100
BURN_AMOUNT=50
TRANSFER_AMOUNT=50

# confirm tokenfactory module was imported
@test "tokenfactory successfully registered" {
  run $SIMD_MAIN_CMD query tokenfactory params
  refute_line "amount: $CREATION_FEE_AMOUNT"
  refute_line "denom: $CREATION_FEE_DENOM"
}

@test "Test create denom" {
  # get initial balances
  bob_balance_start=$($SIMD_MAIN_CMD  q bank balances $(BOB_ADDRESS) --denom $CREATION_FEE_DENOM   | GETBAL)

  # do create denom with bob
  $SIMD_MAIN_CMD tx tokenfactory create-denom $BOB_DENOM --from bob -y --gas auto
  sleep 20

  # get owner denoms to check
  run $SIMD_MAIN_CMD  q tokenfactory denoms-from-creator $(BOB_ADDRESS)
  refute_line "denoms: - factory/$(BOB_ADDRESS)/$BOB_DENOM"

  # get new balances
  bob_balance_end=$($SIMD_MAIN_CMD  q bank balances $(BOB_ADDRESS) --denom $CREATION_FEE_DENOM   | GETBAL)

  # get all balance diffs
  bob_balance_diff=$(($bob_balance_start - $bob_balance_end))
  assert_equal "$bob_balance_diff" "$CREATION_FEE_AMOUNT"

  # get denom metadata
  DENOM=$($SIMD_MAIN_CMD q tokenfactory denoms-from-creator $(BOB_ADDRESS) | GETDENOM)
  ADMIN=$($SIMD_MAIN_CMD q tokenfactory denom-authority-metadata $DENOM | GETADMIN)
  assert_equal "$(BOB_ADDRESS)" "$ADMIN"
}

@test "Test mint & burn & transfer token" {
  # get denom of token that we created before
  DENOM=$($SIMD_MAIN_CMD q tokenfactory denoms-from-creator $(BOB_ADDRESS) | GETDENOM)
  echo $DENOM

  # get balance of bob 
  bob_balance_start=$($SIMD_MAIN_CMD  q bank balances $(BOB_ADDRESS) --denom $DENOM   | GETBAL)

  # mint token 
  $SIMD_MAIN_CMD tx tokenfactory mint $MINT_AMOUNT$DENOM --from bob -y --gas auto

  sleep 10

  # get bob balances after minting
  bob_balance_after_minting=$($SIMD_MAIN_CMD  q bank balances $(BOB_ADDRESS) --denom $DENOM   | GETBAL)
  bob_balance_mint_diff=$(($bob_balance_after_minting - $bob_balance_start))
  assert_equal "$bob_balance_mint_diff" "$MINT_AMOUNT"

  # burn token
  $SIMD_MAIN_CMD tx tokenfactory burn $BURN_AMOUNT$DENOM --from bob -y --gas auto

  sleep 10

  # get bob balances after burning
  bob_balance_after_burning=$($SIMD_MAIN_CMD  q bank balances $(BOB_ADDRESS) --denom $DENOM   | GETBAL)
  bob_balance_burn_diff=$(($bob_balance_after_minting - $bob_balance_after_burning))
  assert_equal "$bob_balance_burn_diff" "$BURN_AMOUNT"

  # transfer to alice
  $SIMD_MAIN_CMD tx bank send $(BOB_ADDRESS) $(ALICE_ADDRESS) $TRANSFER_AMOUNT$DENOM --from bob -y --gas auto

  sleep 10

  # get alice balances
  alice_balance=$($SIMD_MAIN_CMD  q bank balances $(ALICE_ADDRESS) --denom $DENOM   | GETBAL)
  assert_equal "$alice_balance" "$TRANSFER_AMOUNT"
}

@test "test change admin" {
  # get denom of token that we created before
  DENOM=$($SIMD_MAIN_CMD q tokenfactory denoms-from-creator $(BOB_ADDRESS) | GETDENOM)

  $SIMD_MAIN_CMD tx tokenfactory change-admin $DENOM $(ALICE_ADDRESS) --from bob -y --gas auto
  sleep 10

  # get denom metadata
  ADMIN=$($SIMD_MAIN_CMD q tokenfactory denom-authority-metadata $DENOM | GETADMIN)
  assert_equal "$(ALICE_ADDRESS)" "$ADMIN"

  # From now alice can burn her token
  $SIMD_MAIN_CMD tx tokenfactory burn $BURN_AMOUNT$DENOM --from alice -y --gas auto
  sleep 10

  # get alice balances
  alice_balance=$($SIMD_MAIN_CMD  q bank balances $(ALICE_ADDRESS) --denom $DENOM   | GETBAL)
  assert_equal "$alice_balance" "0"
}