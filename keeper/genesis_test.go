package keeper_test

import (
	sdk "github.com/cosmos/cosmos-sdk/types"

	banktypes "github.com/cosmos/cosmos-sdk/x/bank/types"

	"github.com/osmosis-labs/tokenfactory/types"
)

func (s *KeeperTestSuite) TestGenesis() {
	genesisState := types.GenesisState{
		FactoryDenoms: []types.GenesisDenom{
			{
				Denom: "factory/cosmos18nlzrc0da2yny6jz44g3nlhegp77eq5apeau79/bitcoin",
				AuthorityMetadata: types.DenomAuthorityMetadata{
					Admin: "cosmos18nlzrc0da2yny6jz44g3nlhegp77eq5apeau79",
				},
			},
			{
				Denom: "factory/cosmos18nlzrc0da2yny6jz44g3nlhegp77eq5apeau79/diff-admin",
				AuthorityMetadata: types.DenomAuthorityMetadata{
					Admin: "cosmos18nlzrc0da2yny6jz44g3nlhegp77eq5apeau79",
				},
			},
			{
				Denom: "factory/cosmos18nlzrc0da2yny6jz44g3nlhegp77eq5apeau79/litecoin",
				AuthorityMetadata: types.DenomAuthorityMetadata{
					Admin: "cosmos18nlzrc0da2yny6jz44g3nlhegp77eq5apeau79",
				},
			},
		},
	}

	s.SetupTestForInitGenesis()
	app := s.App

	// Test both with bank denom metadata set, and not set.
	for i, denom := range genesisState.FactoryDenoms {
		// hacky, sets bank metadata to exist if i != 0, to cover both cases.
		if i != 0 {
			app.BankKeeper.SetDenomMetaData(s.Ctx, banktypes.Metadata{Base: denom.GetDenom(), Display: "test"})
		}
	}

	// check before initGenesis that the module account is nil
	tokenfactoryModuleAccount := app.AccountKeeper.GetAccount(s.Ctx, app.AccountKeeper.GetModuleAddress(types.ModuleName))
	s.Require().Nil(tokenfactoryModuleAccount)

	app.TokenfactoryKeeper.SetParams(s.Ctx, types.Params{DenomCreationFee: sdk.Coins{sdk.NewInt64Coin("uosmo", 100)}})
	app.TokenfactoryKeeper.InitGenesis(s.Ctx, genesisState)

	// check that the module account is now initialized
	tokenfactoryModuleAccount = app.AccountKeeper.GetAccount(s.Ctx, app.AccountKeeper.GetModuleAddress(types.ModuleName))
	s.Require().NotNil(tokenfactoryModuleAccount)

	exportedGenesis := app.TokenfactoryKeeper.ExportGenesis(s.Ctx)
	s.Require().NotNil(exportedGenesis)
	s.Require().Equal(genesisState, *exportedGenesis)

	app.BankKeeper.SetParams(s.Ctx, banktypes.DefaultParams())
	app.BankKeeper.InitGenesis(s.Ctx, app.BankKeeper.ExportGenesis(s.Ctx))
	for i, denom := range genesisState.FactoryDenoms {
		// hacky, check whether bank metadata is not replaced if i != 0, to cover both cases.
		if i != 0 {
			metadata, found := app.BankKeeper.GetDenomMetaData(s.Ctx, denom.GetDenom())
			s.Require().True(found)
			s.Require().Equal(metadata, banktypes.Metadata{Base: denom.GetDenom(), Display: "test"})
		}
	}
}
