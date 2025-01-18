import path from "path";
import { green, red, yellow } from "./helpers/colorize-log";
import deployedContracts from "../tmp/deployedContracts";
import dotenv from "dotenv";

import { Contract, RpcProvider, Account } from "starknet";

dotenv.config();

async function main() {
  // Configuration
  const preferredChain = process.env.NETWORK;
  console.log(yellow(`Using ${preferredChain} network`));

  const rpcUrl =
    preferredChain === "devnet"
      ? "http://localhost:5050"
      : process.env.RPC_URL_SEPOLIA;
  console.log(yellow(`Using ${rpcUrl} as RPC URL`));

  const deployerPrivateKey =
    preferredChain === "devnet"
      ? "0x564104eda6342ba54f2a698c0342b22b"
      : process.env.PRIVATE_KEY_SEPOLIA;
  const deployerAddress =
    preferredChain === "devnet"
      ? "0x6e1665171388ee560b46a9c321446734fefd29e9c94f969d6ecd0ca21db26aa"
      : process.env.ACCOUNT_ADDRESS_SEPOLIA;

  // Connect to provider and account
  const provider = new RpcProvider({ nodeUrl: rpcUrl });
  const account = new Account(provider, deployerAddress, deployerPrivateKey);
  console.log(green("Account connected successfully"));

  // Load deployed contract addresses

  const verifierAddress = deployedContracts[preferredChain].Verifier.address;
  const verifierAbi = deployedContracts[preferredChain].Verifier.abi;
  const passAddress = deployedContracts[preferredChain].Pass.address;

  // Create contract instances
  const verifierContract = new Contract(verifierAbi, verifierAddress, account);

  try {
    console.log(yellow("Setting pass contract address..."));
    console.log(
      green(
        `Setting Pass (${passAddress}) contract address.`
      )
    );

    const verifierSetCairoVerifierContractTx = verifierContract.populate("set_cairo_verifier_contract", [
      "0x0799065888b54a1164e07f7832d1d356dc9a6b2bc1527aee13b8c55ec5418cf3",
    ]);
    const feeEstimate = await account.estimateFee([verifierSetCairoVerifierContractTx]);

    console.log(yellow(`Estimated fee: ${feeEstimate.overall_fee.toString()}`));

    const buffer = BigInt(200); // 200% buffer
    const maxFee = (feeEstimate.overall_fee * buffer) / BigInt(100); // Apply buffer

    console.log(yellow(`Max fee (with buffer): ${maxFee.toString()}`));

    const result = await account.execute([verifierSetCairoVerifierContractTx], undefined, {
      maxFee: maxFee,
    });

    console.log(
      green(
        `Waiting for transaction ${result.transaction_hash} to be included in a block...`
      )
    );
    await provider.waitForTransaction(result.transaction_hash);
    console.log(green("Initialization completed successfully!"));

    const verifierSetPassContractTx = verifierContract.populate("set_pass_contract", [
      passAddress,
    ]);
    const feeEstimate2 = await account.estimateFee([verifierSetPassContractTx]);

    console.log(yellow(`Estimated fee: ${feeEstimate2.overall_fee.toString()}`));

    const maxFee2 = (feeEstimate2.overall_fee * buffer) / BigInt(100); // Apply buffer

    console.log(yellow(`Max fee (with buffer): ${maxFee.toString()}`));

    const result2 = await account.execute([verifierSetPassContractTx], undefined, {
      maxFee: maxFee2,
    });

    console.log(
      green(
        `Waiting for transaction ${result2.transaction_hash} to be included in a block...`
      )
    );
    await provider.waitForTransaction(result.transaction_hash);
    console.log(green("Initialization completed successfully!"));
  } catch (error) {
    console.error(red("Error during initialization:"), error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
