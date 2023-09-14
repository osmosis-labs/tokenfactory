package simulation

import (
	"errors"
	"math/big"
	"math/rand"

	"github.com/cosmos/cosmos-sdk/baseapp"
	"github.com/cosmos/cosmos-sdk/codec"
	simappparams "github.com/cosmos/cosmos-sdk/simapp/params"
	sdk "github.com/cosmos/cosmos-sdk/types"
	simtypes "github.com/cosmos/cosmos-sdk/types/simulation"
	"github.com/cosmos/cosmos-sdk/x/simulation"

	"github.com/osmosis-labs/tokenfactory/keeper"
	"github.com/osmosis-labs/tokenfactory/types"
)

// Simulation operation weights constants
const (
	OpWeightMsgCreateDenom = "op_weight_msg_create_denom" //nolint:gosec
	OpWeightMsgMintDenom   = "op_weight_msg_mint_denom"   //nolint:gosec
	OpWeightMsgBurnDenom   = "op_weight_msg_burn_denom"   //nolint:gosec
)

// WeightedOperations returns all the operations from the module with their respective weights
func WeightedOperations(
	appParams simtypes.AppParams, cdc codec.JSONCodec, ak types.AccountKeeper,
	bk types.BankKeeper, k keeper.Keeper,
) simulation.WeightedOperations {
	var (
		weightMsgCreateDenom int
		weightMsgMintDenom   int
		weightMsgBurnDenom   int
	)

	appParams.GetOrGenerate(cdc, OpWeightMsgCreateDenom, &weightMsgCreateDenom, nil,
		func(_ *rand.Rand) {
			weightMsgCreateDenom = simappparams.DefaultWeightMsgSend
		},
	)
	appParams.GetOrGenerate(cdc, OpWeightMsgMintDenom, &weightMsgMintDenom, nil,
		func(_ *rand.Rand) {
			weightMsgMintDenom = simappparams.DefaultWeightMsgSend
		},
	)
	appParams.GetOrGenerate(cdc, OpWeightMsgMintDenom, &weightMsgMintDenom, nil,
		func(_ *rand.Rand) {
			weightMsgBurnDenom = simappparams.DefaultWeightMsgSend
		},
	)

	return simulation.WeightedOperations{
		simulation.NewWeightedOperation(
			weightMsgCreateDenom,
			SimulateMsgCreateDenom(ak, bk, k),
		),
		simulation.NewWeightedOperation(
			weightMsgMintDenom,
			SimulateMsgMintDenom(ak, bk, k),
		),
		simulation.NewWeightedOperation(
			weightMsgBurnDenom,
			SimulateMsgBurnDenom(ak, bk, k),
		),
	}
}

func SimulateMsgCreateDenom(ak types.AccountKeeper, bk types.BankKeeper, k keeper.Keeper) simtypes.Operation {
	return func(
		r *rand.Rand, app *baseapp.BaseApp, ctx sdk.Context, accs []simtypes.Account, chainID string,
	) (simtypes.OperationMsg, []simtypes.FutureOperation, error) {
		minCoins := k.GetParams(ctx).DenomCreationFee

		acc, err := RandomSimAccountWithMinCoins(ctx, bk, r, accs, minCoins)
		if err != nil {
			return simtypes.NoOpMsg(types.ModuleName, types.TypeMsgCreateDenom, "no address with min balance found"), nil, err
		}

		radnStringOfLength := simtypes.RandStringOfLength(r, types.MaxSubdenomLength)
		msg := &types.MsgCreateDenom{
			Sender:   acc.Address.String(),
			Subdenom: radnStringOfLength,
		}

		txCtx := simulation.OperationInput{
			R:             r,
			App:           app,
			TxGen:         simappparams.MakeTestEncodingConfig().TxConfig,
			Cdc:           nil,
			Msg:           msg,
			MsgType:       msg.Type(),
			Context:       ctx,
			SimAccount:    acc,
			AccountKeeper: ak,
			ModuleName:    types.ModuleName,
		}

		return simulation.GenAndDeliverTxWithRandFees(txCtx)
	}
}

// SimulateMsgMintDenom takes a random denom that has been created and uses the denom's admin to mint a random amount
func SimulateMsgMintDenom(ak types.AccountKeeper, bk types.BankKeeper, k keeper.Keeper) simtypes.Operation {
	return func(
		r *rand.Rand, app *baseapp.BaseApp, ctx sdk.Context, accs []simtypes.Account, chainID string,
	) (simtypes.OperationMsg, []simtypes.FutureOperation, error) {
		acc, senderExists := RandomSimAccountWithConstraint(r, accs, accountCreatedTokenFactoryDenom(k, ctx))
		if !senderExists {
			return simtypes.NoOpMsg(types.ModuleName, types.TypeMsgMint, "no addr has created a tokenfactory coin"), nil, errors.New("no addr has created a tokenfactory coin")
		}

		denom, addr, err := getTokenFactoryDenomAndItsAdmin(k, r, ctx, acc)
		if err != nil {
			return simtypes.NoOpMsg(types.ModuleName, types.TypeMsgMint, "error while getting token factory denom and admin"), nil, err
		}
		if addr == nil {
			return simtypes.NoOpMsg(types.ModuleName, types.TypeMsgMint, "no admin for tokenfactory denom"), nil, err
		}

		// TODO: Replace with an improved rand exponential coin
		mintAmount, err := RandPositiveInt(r, sdk.NewIntFromUint64(1000_000000))
		msg := &types.MsgMint{
			Sender: addr.String(),
			Amount: sdk.NewCoin(denom, mintAmount),
		}

		txCtx := simulation.OperationInput{
			R:             r,
			App:           app,
			TxGen:         simappparams.MakeTestEncodingConfig().TxConfig,
			Cdc:           nil,
			Msg:           msg,
			MsgType:       msg.Type(),
			Context:       ctx,
			SimAccount:    acc,
			AccountKeeper: ak,
			ModuleName:    types.ModuleName,
		}

		return simulation.GenAndDeliverTxWithRandFees(txCtx)
	}
}

func SimulateMsgBurnDenom(ak types.AccountKeeper, bk types.BankKeeper, k keeper.Keeper) simtypes.Operation {
	return func(
		r *rand.Rand, app *baseapp.BaseApp, ctx sdk.Context, accs []simtypes.Account, chainID string,
	) (simtypes.OperationMsg, []simtypes.FutureOperation, error) {
		acc, senderExists := RandomSimAccountWithConstraint(r, accs, accountCreatedTokenFactoryDenom(k, ctx))
		if !senderExists {
			return simtypes.NoOpMsg(types.ModuleName, types.TypeMsgBurn, "no addr has created a tokenfactory coin"), nil, errors.New("no addr has created a tokenfactory coin")
		}

		denom, addr, err := getTokenFactoryDenomAndItsAdmin(k, r, ctx, acc)
		if err != nil {
			return simtypes.NoOpMsg(types.ModuleName, types.TypeMsgBurn, "error while getting token factory denom and admin"), nil, err
		}
		if addr == nil {
			return simtypes.NoOpMsg(types.ModuleName, types.TypeMsgBurn, "denom has no admin"), nil, errors.New("denom has no admin")
		}

		denomBal := bk.GetBalance(ctx, addr, denom)
		if denomBal.IsZero() {
			return simtypes.NoOpMsg(types.ModuleName, types.TypeMsgBurn, "addr does not have enough balance to burn"), nil, errors.New("addr does not have enough balance to burn")
		}

		// TODO: Replace with an improved rand exponential coin
		burnAmount, err := RandPositiveInt(r, denomBal.Amount)
		if err != nil {
			return simtypes.NoOpMsg(types.ModuleName, types.TypeMsgBurn, "error generating burn amount"), nil, err
		}
		msg := &types.MsgBurn{
			Sender: addr.String(),
			Amount: sdk.NewCoin(denom, burnAmount),
		}

		txCtx := simulation.OperationInput{
			R:             r,
			App:           app,
			TxGen:         simappparams.MakeTestEncodingConfig().TxConfig,
			Cdc:           nil,
			Msg:           msg,
			MsgType:       msg.Type(),
			Context:       ctx,
			SimAccount:    acc,
			AccountKeeper: ak,
			ModuleName:    types.ModuleName,
		}

		return simulation.GenAndDeliverTxWithRandFees(txCtx)
	}
}
func SimulateMsgChangeAdmin(ak types.AccountKeeper, bk types.BankKeeper, k keeper.Keeper) simtypes.Operation {
	return func(
		r *rand.Rand, app *baseapp.BaseApp, ctx sdk.Context, accs []simtypes.Account, chainID string,
	) (simtypes.OperationMsg, []simtypes.FutureOperation, error) {

		acc, senderExists := RandomSimAccountWithConstraint(r, accs, accountCreatedTokenFactoryDenom(k, ctx))
		if !senderExists {
			return simtypes.NoOpMsg(types.ModuleName, types.TypeMsgChangeAdmin, "no addr has created a tokenfactory coin"), nil, errors.New("no addr has created a tokenfactory coin")
		}

		denom, addr, err := getTokenFactoryDenomAndItsAdmin(k, r, ctx, acc)
		if err != nil {
			return simtypes.NoOpMsg(types.ModuleName, types.TypeMsgChangeAdmin, "error while getting token factory denom and admin"), nil, err
		}
		if addr == nil {
			return simtypes.NoOpMsg(types.ModuleName, types.TypeMsgChangeAdmin, "denom has no admin"), nil, errors.New("denom has no admin")
		}

		newAdmin := randomSimAccount(r, accs)
		if newAdmin.Address.String() == addr.String() {
			return simtypes.NoOpMsg(types.ModuleName, types.TypeMsgChangeAdmin, "new admin cannot be the same as current admin"), nil, errors.New("new admin cannot be the same as current admin")
		}

		msg := &types.MsgChangeAdmin{
			Sender:   addr.String(),
			Denom:    denom,
			NewAdmin: newAdmin.Address.String(),
		}

		txCtx := simulation.OperationInput{
			R:             r,
			App:           app,
			TxGen:         simappparams.MakeTestEncodingConfig().TxConfig,
			Cdc:           nil,
			Msg:           msg,
			MsgType:       msg.Type(),
			Context:       ctx,
			SimAccount:    acc,
			AccountKeeper: ak,
			ModuleName:    types.ModuleName,
		}

		return simulation.GenAndDeliverTxWithRandFees(txCtx)
	}
}

func RandomSimAccountWithMinCoins(ctx sdk.Context, bk types.BankKeeper, r *rand.Rand, accounts []simtypes.Account, coins sdk.Coins) (simtypes.Account, error) {
	accHasMinCoins := func(acc simtypes.Account) bool {
		spendableCoins := bk.SpendableCoins(ctx, acc.Address)
		return spendableCoins.IsAllGTE(coins) && coins.DenomsSubsetOf(spendableCoins)
	}
	acc, found := RandomSimAccountWithConstraint(r, accounts, accHasMinCoins)
	if !found {
		return simtypes.Account{}, errors.New("no address with min balance found.")
	}
	return acc, nil
}

type SimAccountConstraint = func(account simtypes.Account) bool

func RandomSimAccountWithConstraint(r *rand.Rand, accounts []simtypes.Account, f SimAccountConstraint) (simtypes.Account, bool) {
	filteredAddrs := []simtypes.Account{}
	for _, acc := range accounts {
		if f(acc) {
			filteredAddrs = append(filteredAddrs, acc)
		}
	}

	if len(filteredAddrs) == 0 {
		return simtypes.Account{}, false
	}
	return randomSimAccount(r, filteredAddrs), true
}

func randomSimAccount(r *rand.Rand, accs []simtypes.Account) simtypes.Account {
	idx := r.Intn(len(accs))
	return accs[idx]
}

func accountCreatedTokenFactoryDenom(k keeper.Keeper, ctx sdk.Context) SimAccountConstraint {
	return func(acc simtypes.Account) bool {
		store := k.GetCreatorPrefixStore(ctx, acc.Address.String())
		iterator := store.Iterator(nil, nil)
		defer iterator.Close()
		return iterator.Valid()
	}
}

func getTokenFactoryDenomAndItsAdmin(k keeper.Keeper, r *rand.Rand, ctx sdk.Context, acc simtypes.Account) (string, sdk.AccAddress, error) {
	store := k.GetCreatorPrefixStore(ctx, acc.Address.String())
	denoms := gatherAllKeysFromStore(store)
	denom := randSelect(r, denoms...)

	authData, err := k.GetAuthorityMetadata(ctx, denom)
	if err != nil {
		return "", nil, err
	}
	admin := authData.Admin
	addr, err := sdk.AccAddressFromBech32(admin)
	if err != nil {
		return "", nil, err
	}
	return denom, addr, nil
}

func randLTBound(r *rand.Rand, upperbound int) int {
	return randLTEBound(r, upperbound-1)
}

func randLTEBound(r *rand.Rand, upperbound int) int {
	return r.Intn(upperbound + 1)
}

func randSelect[T interface{}](r *rand.Rand, args ...T) T {
	choice := randLTBound(r, len(args))
	return args[choice]
}

func randIntBetween(r *rand.Rand, min, max int) int {
	return r.Intn(max-min+1) + min
}

func RandPositiveInt(r *rand.Rand, max sdk.Int) (sdk.Int, error) {
	if !max.GTE(sdk.OneInt()) {
		return sdk.Int{}, errors.New("max too small")
	}

	max = max.Sub(sdk.OneInt())

	return sdk.NewIntFromBigInt(new(big.Int).Rand(r, max.BigInt())).Add(sdk.OneInt()), nil
}

func gatherAllKeysFromStore(store sdk.KVStore) []string {
	keys := []string{}
	iterator := store.Iterator(nil, nil)
	defer iterator.Close()

	for ; iterator.Valid(); iterator.Next() {
		key := string(iterator.Key())
		keys = append(keys, key)
	}

	return keys
}
