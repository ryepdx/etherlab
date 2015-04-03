#!/bin/bash

# This is a terrible way to do this, but it was easy and it works.
cat lib/interfaces/*.sol lib/owned.sol lib/action.sol lib/protectedApi.sol lib/ownedApiEnabled.sol lib/protectedContract.sol lib/persistentProtectedContract.sol lib/permissionsProviderProperty.sol lib/ownersDb.sol lib/directDemocracy.sol > build/directDemocracy.sol
solc build/directDemocracy.sol
