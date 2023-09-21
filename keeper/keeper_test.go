package keeper_test

import (
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/cosmos/cosmos-sdk/baseapp"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/stretchr/testify/suite"
	"github.com/tendermint/tendermint/crypto/ed25519"
	tmproto "github.com/tendermint/tendermint/proto/tendermint/types"
	tmtypes "github.com/tendermint/tendermint/proto/tendermint/types"

	bankkeeper "github.com/cosmos/cosmos-sdk/x/bank/keeper"
	banktypes "github.com/cosmos/cosmos-sdk/x/bank/types"

	"github.com/osmosis-labs/tokenfactory/keeper"
	"github.com/osmosis-labs/tokenfactory/simapp"
	"github.com/osmosis-labs/tokenfactory/types"
)

type KeeperTestSuite struct {
	suite.Suite

	App         *simapp.SimApp
	Ctx         sdk.Context
	QueryHelper *baseapp.QueryServiceTestHelper
	TestAccs    []sdk.AccAddress

	queryClient   types.QueryClient
	msgServer     types.MsgServer
	bankMsgServer banktypes.MsgServer

	// defaultDenom is on the suite, as it depends on the creator test address.
	defaultDenom string
}

var (
	baseTestAccts        = []sdk.AccAddress{}
	defaultTestStartTime = time.Now().UTC()
)

func init() {
	baseTestAccts = CreateRandomAccounts(3)
}

// CreateRandomAccounts is a function return a list of randomly generated AccAddresses
func CreateRandomAccounts(numAccts int) []sdk.AccAddress {
	testAddrs := make([]sdk.AccAddress, numAccts)
	for i := 0; i < numAccts; i++ {
		pk := ed25519.GenPrivKey().PubKey()
		testAddrs[i] = sdk.AccAddress(pk.Address())
	}

	return testAddrs
}

func TestKeeperTestSuite(t *testing.T) {
	suite.Run(t, new(KeeperTestSuite))
}

func (s *KeeperTestSuite) SetupTest() {
	dir, err := os.MkdirTemp("", "osmosisd-test-home")
	if err != nil {
		panic(fmt.Sprintf("failed creating temporary directory: %v", err))
	}
	s.T().Cleanup(func() { os.RemoveAll(dir) })
	s.App = simapp.Setup(false)
	s.Ctx = s.App.BaseApp.NewContext(false, tmtypes.Header{Height: 1, ChainID: "osmosis-1", Time: defaultTestStartTime})

	s.QueryHelper = &baseapp.QueryServiceTestHelper{
		GRPCQueryRouter: s.App.GRPCQueryRouter(),
		Ctx:             s.Ctx,
	}

	s.TestAccs = []sdk.AccAddress{}
	s.TestAccs = append(s.TestAccs, baseTestAccts...)

	s.queryClient = types.NewQueryClient(s.QueryHelper)
	s.msgServer = keeper.NewMsgServerImpl(s.App.TokenfactoryKeeper)
	s.bankMsgServer = bankkeeper.NewMsgServerImpl(s.App.BankKeeper)
}

// FundAcc funds target address with specified amount.
func (s *KeeperTestSuite) FundAcc(acc sdk.AccAddress, amounts sdk.Coins) {
	err := simapp.FundAccount(s.App.BankKeeper, s.Ctx, acc, amounts)
	s.Require().NoError(err)
}

func (s *KeeperTestSuite) CreateDefaultDenom() {
	res, _ := s.msgServer.CreateDenom(sdk.WrapSDKContext(s.Ctx), types.NewMsgCreateDenom(s.TestAccs[0].String(), "bitcoin"))
	s.defaultDenom = res.GetNewTokenDenom()
}

func (s *KeeperTestSuite) TestCreateModuleAccount() {
	app := s.App

	// setup new next account number
	nextAccountNumber := app.AccountKeeper.GetNextAccountNumber(s.Ctx)

	// remove module account
	tokenfactoryModuleAccount := app.AccountKeeper.GetAccount(s.Ctx, app.AccountKeeper.GetModuleAddress(types.ModuleName))
	app.AccountKeeper.RemoveAccount(s.Ctx, tokenfactoryModuleAccount)

	// ensure module account was removed
	s.Ctx = app.BaseApp.NewContext(false, tmproto.Header{})
	tokenfactoryModuleAccount = app.AccountKeeper.GetAccount(s.Ctx, app.AccountKeeper.GetModuleAddress(types.ModuleName))
	s.Require().Nil(tokenfactoryModuleAccount)

	// create module account
	app.TokenfactoryKeeper.CreateModuleAccount(s.Ctx)

	// check that the module account is now initialized
	tokenfactoryModuleAccount = app.AccountKeeper.GetAccount(s.Ctx, app.AccountKeeper.GetModuleAddress(types.ModuleName))
	s.Require().NotNil(tokenfactoryModuleAccount)

	// check that the account number of the module account is now initialized correctly
	s.Require().Equal(nextAccountNumber+1, tokenfactoryModuleAccount.GetAccountNumber())
}

func (s *KeeperTestSuite) SetupTestForInitGenesis() {
	// Setting to True, leads to init genesis not running
	s.App = simapp.Setup(true)
	s.Ctx = s.App.BaseApp.NewContext(true, tmtypes.Header{})
}

// AssertEventEmitted asserts that ctx's event manager has emitted the given number of events
// of the given type.
func (s *KeeperTestSuite) AssertEventEmitted(ctx sdk.Context, eventTypeExpected string, numEventsExpected int) {
	allEvents := ctx.EventManager().Events()
	// filter out other events
	actualEvents := make([]sdk.Event, 0)
	for _, event := range allEvents {
		if event.Type == eventTypeExpected {
			actualEvents = append(actualEvents, event)
		}
	}
	s.Require().Equal(numEventsExpected, len(actualEvents))
}

// FundModuleAcc funds target modules with specified amount.
func (s *KeeperTestSuite) FundModuleAcc(moduleName string, amounts sdk.Coins) {
	err := simapp.FundModuleAccount(s.App.BankKeeper, s.Ctx, moduleName, amounts)
	s.Require().NoError(err)
}
