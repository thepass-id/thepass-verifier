# ThePass

<h4 align="center">
  <a href="">Documentation</a> |
  <a href="">Website</a> |
  <a href="">Demo</a>
</h4>

🎟 ThePass is an open-source project focused on enabling secure verification of data through Zero-Knowledge Proofs (ZKPs). With ThePass, you can validate the correctness of a statement or data without exposing any sensitive information or the actual data being verified.

## Requirements

Before you begin, you need to install the following tools:

- [Node (>= v18.17)](https://nodejs.org/en/download/)
- Yarn ([v1](https://classic.yarnpkg.com/en/docs/install/) or [v2+](https://yarnpkg.com/getting-started/install))
- [Git](https://git-scm.com/downloads)
- [Rust](https://www.rust-lang.org/tools/install)
- [asdf](https://asdf-vm.com/guide/getting-started.html)
- [Cairo 1.0 extension for VSCode](https://marketplace.visualstudio.com/items?itemName=starkware.cairo1)

### Starknet-devnet version

To ensure the proper functioning of ThePass, your local `starknet-devnet` version must be `0.2.0`. To accomplish this, first check your local starknet-devnet version:

```sh
starknet-devnet --version
```

If your local starknet-devnet version is not `0.2.0`, you need to install it.

- Install Starknet-devnet `0.2.0` via `asdf` ([instructions](https://github.com/gianalarcon/asdf-starknet-devnet/blob/main/README.md)).

### Scarb version

To ensure the proper functioning of ThePass, your local `Scarb` version must be `2.8.3`. To accomplish this, first check your local Scarb version:

```sh
scarb --version
```

If your local Scarb version is not `2.8.3`, you need to install it.

- Install Scarb `2.8.3` via `asdf` ([instructions](https://docs.swmansion.com/scarb/download.html#install-via-asdf)).

### Starknet Foundry version

To ensure the proper functioning of the tests on ThePass, your Starknet Foundry version must be 0.31.0. To accomplish this, first check your Starknet Foundry version:

```sh
snforge --version
```

If your Starknet Foundry version is not `0.31.0`, you need to install it.

- Install Starknet Foundry `0.31.0` via `asdf` ([instructions](https://foundry-rs.github.io/starknet-foundry/getting-started/installation.html#installation-via-asdf)).

## Compatible versions

- Starknet-devnet - v0.2.0
- Scarb - v2.8.3
- Snforge - v0.31.0
- Cairo - v2.8.2
- Rpc - v0.7.1

## Quickstart with Starknet-Devnet

To get started with ThePass, follow the steps below:

1. Clone this repo and install dependencies

```bash
git clone https://github.com/thepassid/ThePass.git
cd ThePass
yarn install
```

2. Run a local network in the first terminal.

```bash
yarn chain
```

> To run a fork : `yarn chain --fork-network <URL> [--fork-block <BLOCK_NUMBER>]`

This command starts a local Starknet network using Devnet. The network runs on your local machine and can be used for testing and development.

3. On a second terminal, deploy the sample contract:

```bash
yarn deploy
```

This command deploys a sample smart contract to the local network. The contract is located in `contracts/src` and can be modified to suit your needs. The `yarn deploy` command uses the deploy script located in `scripts/deploy.ts` to deploy the contract to the network. You can also customize the deploy script.

By default `ThePass` takes the first prefunded account from `starknet-devnet` as a deployer address,

4. On a third terminal, start your NextJS app:

```bash
yarn start
```

Visit your app on: `http://localhost:3000`. You can interact with your smart contract using the `Debug Contracts` page.

5. Check your environment variables. We have a yarn postinstall script that helps to fill in your environment variables. If the environment variable does not exist, you can fill them it manually to get the app running!

## Quickstart with Sepolia Testnet

<details>

1. Make sure you alredy cloned this repo and installed dependencies.

2. Prepare your environment variables.

Find the `.env` file and fill the env variables related to Sepolia testnet with your own wallet account contract address and private key.

3. Change your default network to Sepolia testnet.

4. Get some testnet tokens

You will need to get some `ETH` or `STRK` Sepolia tokens to deploy your contract to Sepolia testnet.

> Some popular faucets are [Starknet Faucet](https://starknet-faucet.vercel.app/) and [Blastapi Starknet Sepolia Eth](https://blastapi.io/faucets/starknet-sepolia-eth)

4. Open a terminal, deploy the sample contract to Sepolia testnet:

```bash
yarn deploy --network sepolia
```

5. On a second terminal, start your NextJS app:

```bash
yarn start
```

Visit your app on: `http://localhost:3000`. You can interact with your smart contract using the `Debug Contracts` page.

### RPC specific version

To ensure the proper functioning of the ThePass with Testnet or Mainnet, your RPC version must be `0.7.1`. This repository contains a `.env.example` file, where we provided the default RPC URL for the Starknet Testnet: `RPC_URL_SEPOLIA=https://starknet-sepolia.public.blastapi.io/rpc/v0_7`. Let's verify this RPC version is `0.7.1` by calling a `POST` request in an API platform like `Postman` or `Insommia` . Your API endpoint should be `https://starknet-sepolia.public.blastapi.io/rpc/v0_7` and the body should be:

```json
{
 "jsonrpc":"2.0",
 "method":"starknet_specVersion",
 "id":1
}
```

You have to paste the endpoint and body in the API platform and click on the `Send` button. If the response is `0.7.1`, then you are good to go. Otherwise, you have to get the correct RPC URL endpoint.
</details>

## Documentation

Visit our [docs]() to learn how to start building with ThePass.

To know more about its features, check out our [website]()

## Contributing to ThePass

We welcome contributions to ThePass!

Please see [CONTRIBUTING.MD](https://github.com/thepassid/ThePass/blob/main/CONTRIBUTING.md) for more information and guidelines for contributing to ThePass.
