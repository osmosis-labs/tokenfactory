package cli

import (

	// "strings"

	"fmt"

	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/client/flags"
	"github.com/spf13/cobra"

	"github.com/osmosis-labs/tokenfactory/types"
)

// GetQueryCmd returns the cli query commands for this module
func GetQueryCmd() *cobra.Command {

	cmd := &cobra.Command{
		Use:                        types.ModuleName,
		Short:                      fmt.Sprintf("Querying commands for the %s module", types.ModuleName),
		DisableFlagParsing:         true,
		SuggestionsMinimumDistance: 2,
		RunE:                       client.ValidateCmd,
	}

	cmd.AddCommand(
		GetCmdDenomAuthorityMetadata(),
		GetCmdDenomsFromCreator(),
		GetCmdDenomBeforeSendHook(),
	)

	return cmd
}

func GetCmdDenomAuthorityMetadata() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "denom-authority-metadata [denom]",
		Args:  cobra.ExactArgs(1),
		Short: "Get the authority metadata for a specific denom",
		Long:  "Get the authority metadata for a specific denom",
		RunE: func(cmd *cobra.Command, args []string) error {
			clientCtx, err := client.GetClientQueryContext(cmd)
			if err != nil {
				return err
			}

			queryClient := types.NewQueryClient(clientCtx)
			res, err := queryClient.DenomAuthorityMetadata(cmd.Context(), &types.QueryDenomAuthorityMetadataRequest{
				Denom: args[0],
			})
			if err != nil {
				return err
			}

			return clientCtx.PrintProto(res)
		},
	}

	flags.AddQueryFlagsToCmd(cmd)

	return cmd
}

func GetCmdDenomsFromCreator() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "denoms-from-creator [creator]",
		Args:  cobra.ExactArgs(1),
		Short: "Returns a list of all tokens created by a specific creator address",
		Long:  "Returns a list of all tokens created by a specific creator address",
		RunE: func(cmd *cobra.Command, args []string) error {
			clientCtx, err := client.GetClientQueryContext(cmd)
			if err != nil {
				return err
			}

			queryClient := types.NewQueryClient(clientCtx)
			res, err := queryClient.DenomsFromCreator(cmd.Context(), &types.QueryDenomsFromCreatorRequest{
				Creator: args[0],
			})
			if err != nil {
				return err
			}

			return clientCtx.PrintProto(res)
		},
	}

	flags.AddQueryFlagsToCmd(cmd)

	return cmd
}

func GetCmdDenomBeforeSendHook() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "denom-before-send-hook [denom] [flags]",
		Short: "Get the BeforeSend hook for a specific denom",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			clientCtx, err := client.GetClientQueryContext(cmd)
			if err != nil {
				return err
			}
			queryClient := types.NewQueryClient(clientCtx)

			res, err := queryClient.BeforeSendHookAddress(cmd.Context(), &types.QueryBeforeSendHookAddressRequest{
				Denom: args[0],
			})
			if err != nil {
				return err
			}

			return clientCtx.PrintProto(res)
		},
	}

	flags.AddQueryFlagsToCmd(cmd)

	return cmd
}
