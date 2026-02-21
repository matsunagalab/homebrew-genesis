# homebrew-genesis

Homebrew tap for [GENESIS](https://www.r-ccs.riken.jp/labs/cbrt/)
(GENeralized-Ensemble SImulation System).

## Installation

    brew tap matsunagalab/genesis
    brew install genesis

## What gets installed

- `spdyn` - Spatial decomposition parallel MD simulator
- `atdyn` - Atomic decomposition MD simulator
- 39+ analysis and utility tools

## Usage

    mpirun -np 4 spdyn input_file
    atdyn input_file
