`/dockernet` contains infrastructure that is used for testing. The scripts here support docker-image based testing.

## Testing

* The purpose is to ensure that the main functions of the tokenfactory operate perfectly on any chain. So we set up a simulated environment on dockernet to test.

* The main files that need attention:
    * dockernet/build.sh: build simd that will be used in docker
    * dockernet/config.sh: contains config variables
    * dockernet/tests/integration_tests.sh: contains test logics here

* Test cases:
    * Make sure any user can create their own denoms.
    * Token that created can be mint, burn by admin and can be transfered.
    * Have denom meatadata.
    * User can transfer admin permission to other user.

## Steps

* Start the network as normal.  You can view the logs in `dockernet/logs` to ensure the network started successfully.
```
make build-docker
make start-docker
```

* After the chain is running, run the integration tests to confirm `tokenfactory` work on new chain.
```
make test-integration-docker
```