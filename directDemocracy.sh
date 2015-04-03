#!/bin/bash

# Requires Preprocessor.js
preprocess lib/democracy/directDemocracy.sol lib > build/directDemocracy.sol
solc build/directDemocracy.sol
