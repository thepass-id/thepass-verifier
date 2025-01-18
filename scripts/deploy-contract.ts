import fs from "fs";
import path from "path";
import { networks } from "./helpers/networks";
import yargs from "yargs";
import {
  CallData,
  stark,
  RawArgs,
  transaction,
  extractContractHashes,
  DeclareContractPayload,
  UniversalDetails,
  isSierra,
  TransactionReceipt,
  BigNumberish,
} from "starknet";
import { DeployContractParams, DeclareContractParams, Network } from "./types";
import { green, red, yellow } from "./helpers/colorize-log";
import { getTxVersion } from "./helpers/fees";

interface Arguments {
  network: string;
  reset: boolean;
  fee?: string;
  [x: string]: unknown;
  _: (string | number)[];
  $0: string;
}

const argv = yargs(process.argv.slice(2))
  .option("network", {
    type: "string",
    description: "Specify the network",
    demandOption: true,
  })
  .option("reset", {
    alias: "nr",
    type: "boolean",
    description:
      "(--no-reset) Do not reset deployments (keep existing deployments)",
    default: true,
  })
  .option("fee", {
    type: "string",
    description: "Specify the fee token",
    demandOption: false,
    choices: ["eth", "strk"],
    default: "eth",
  })
  .parseSync() as Arguments;

const networkName: string = argv.network;
const resetDeployments: boolean = argv.reset;
const feeToken: string = argv.fee!;

interface ICall {
  contractAddress: string;
  entrypoint: string;
  calldata: BigNumberish[];
}

interface IBuildUDCCall {
  calls: ICall[];
  addresses: string[];
}

let deployments = {};
let deployCalls: ICall[] = [];

const { provider, deployer }: Network = networks[networkName];

const declareIfNot_NotWait = async (
  payload: DeclareContractPayload,
  options?: UniversalDetails
) => {
  const declareContractPayload = extractContractHashes(payload);
  try {
    await provider.getClassByHash(declareContractPayload.classHash);
  } catch (error) {
    try {
      const isSierraContract = isSierra(payload.contract);
      const txVersion = await getTxVersion(
        networks[networkName],
        feeToken,
        isSierraContract
      );
      const { transaction_hash } = await deployer.declare(payload, {
        ...options,
        version: txVersion,
      });
      if (networkName === "sepolia" || networkName === "mainnet") {
        await provider.waitForTransaction(transaction_hash);
      }
    } catch (e) {
      console.log(e.message);
      const errorDetails = {
        message: e.message,
        stack: e.stack,
        time: new Date().toISOString(),
      };
      try {
        await fs.promises.writeFile('error_log.json', JSON.stringify(errorDetails, null, 2));
      } catch (writeError) {
        console.error("Error writing to file:", writeError);
      }
      throw e;
      //console.error(red("Error declaring contract:"), e);
    }
  }
  return {
    classHash: declareContractPayload.classHash,
  };
};

const deployContract_NotWait = async (payload: {
  salt: string;
  classHash: string;
  constructorCalldata: RawArgs;
}) => {
  try {
    const { calls, addresses } = transaction.buildUDCCall(
      payload,
      deployer.address
    );

    deployCalls.push(...calls);
    return {
      contractAddress: addresses[0],
    };
  } catch (error) {
    console.error(red("Error building UDC call:"), error);
    throw error;
  }
};

const deployContract = async (
  params: DeployContractParams
): Promise<{
  classHash: string;
  address: string;
}> => {
  const { contract, constructorArgs, contractName, options } = params;

  try {
    await deployer.getContractVersion(deployer.address);
  } catch (e) {
    if (e.toString().includes("Contract not found")) {
      const errorMessage = `The wallet you're using to deploy the contract is not deployed in the ${networkName} network.`;
      console.error(red(errorMessage));
      throw new Error(errorMessage);
    } else {
      console.error(red("Error getting contract version: "), e);
      throw e;
    }
  }

  let compiledContractCasm;
  let compiledContractSierra;

  try {
    compiledContractCasm = JSON.parse(
      fs
        .readFileSync(
          path.resolve(
            __dirname,
            `../contracts/target/dev/thepass_${contract}.compiled_contract_class.json`
          )
        )
        .toString("ascii")
    );
  } catch (error) {
    if (
      typeof error.message === "string" &&
      error.message.includes("no such file") &&
      error.message.includes("compiled_contract_class")
    ) {
      const match = error.message.match(
        /\/dev\/(.+?)\.compiled_contract_class/
      );
      const missingContract = match ? match[1].split("_").pop() : "Unknown";
      console.error(
        red(
          `The contract "${missingContract}" doesn't exist or is not compiled`
        )
      );
    } else {
      console.error(red("Error reading compiled contract class file: "), error);
    }
    return {
      classHash: "",
      address: "",
    };
  }

  try {
    compiledContractSierra = JSON.parse(
      fs
        .readFileSync(
          path.resolve(
            __dirname,
            `../contracts/target/dev/thepass_${contract}.contract_class.json`
          )
        )
        .toString("ascii")
    );
  } catch (error) {
    console.error(red("Error reading contract class file: "), error);
    return {
      classHash: "",
      address: "",
    };
  }

  const contractCalldata = new CallData(compiledContractSierra.abi);
  const constructorCalldata = constructorArgs
    ? contractCalldata.compile("constructor", constructorArgs)
    : [];

  console.log(yellow("Deploying Contract "), contractName || contract);

  let { classHash } = await declareIfNot_NotWait(
    {
      contract: compiledContractSierra,
      casm: compiledContractCasm,
    },
    options
  );

  let randomSalt = stark.randomAddress();

  let { contractAddress } = await deployContract_NotWait({
    salt: randomSalt,
    classHash,
    constructorCalldata,
  });

  console.log(green("Contract Deployed at "), contractAddress);

  let finalContractName = contractName || contract;

  deployments[finalContractName] = {
    classHash: classHash,
    address: contractAddress,
    contract: contract,
  };

  return {
    classHash: classHash,
    address: contractAddress,
  };
};

const declareContract = async (
  params: DeclareContractParams
): Promise<{ classHash: string }> => {
  const { contract, options } = params;

  let compiledContractCasm;
  let compiledContractSierra;

  try {
    // Load the CASM file for the contract
    compiledContractCasm = JSON.parse(
      fs
        .readFileSync(
          path.resolve(
            __dirname,
            `../contracts/target/dev/thepass_${contract}.compiled_contract_class.json`
          )
        )
        .toString("ascii")
    );
  } catch (error) {
    console.error(
      red(
        `Error loading CASM file for contract "${contract}": ${error.message}`
      )
    );
    throw new Error(`Failed to load CASM file for contract "${contract}"`);
  }

  try {
    compiledContractSierra = JSON.parse(
      fs
        .readFileSync(
          path.resolve(
            __dirname,
            `../contracts/target/dev/thepass_${contract}.contract_class.json`
          )
        )
        .toString("ascii")
    );
  } catch (error) {
    console.error(
      red(
        `Error loading Sierra file for contract "${contract}": ${error.message}`
      )
    );
    throw new Error(`Failed to load Sierra file for contract "${contract}"`);
  }

  console.log(yellow("Declaring Contract "), contract);

  const { classHash } = await declareIfNot_NotWait(
    {
      contract: compiledContractSierra,
      casm: compiledContractCasm,
    },
    options
  );

  console.log(green("Contract Declared with class hash: "), classHash);

  return { classHash };
};

const executeDeployCalls = async (options?: UniversalDetails) => {
  if (deployCalls.length < 1) {
    throw new Error(
      red(
        "Aborted: No contract to deploy. Please prepare the contracts with `deployContract`"
      )
    );
  }

  try {
    const txVersion = await getTxVersion(networks[networkName], feeToken);
    let { transaction_hash } = await deployer.execute(deployCalls, {
      ...options,
      version: txVersion,
    });
    if (networkName === "sepolia" || networkName === "mainnet") {
      const receipt = (await provider.waitForTransaction(
        transaction_hash
      )) as TransactionReceipt;
      if (receipt.execution_status !== "SUCCEEDED") {
        const revertReason = receipt.revert_reason;
        throw new Error(red(`Deploy Calls Failed: ${revertReason}`));
      }
    }
    console.log(green("Deploy Calls Executed at "), transaction_hash);
  } catch (error) {
    // split the calls in half and try again recursively
    if (deployCalls.length > 100) {
      let half = Math.ceil(deployCalls.length / 2);
      let firstHalf = deployCalls.slice(0, half);
      let secondHalf = deployCalls.slice(half);
      deployCalls = firstHalf;
      await executeDeployCalls(options);
      deployCalls = secondHalf;
      await executeDeployCalls(options);
    } else {
      throw error;
    }
  }
};

const loadExistingDeployments = () => {
  const networkPath = path.resolve(
    __dirname,
    `../deployments/${networkName}_latest.json`
  );
  if (fs.existsSync(networkPath)) {
    return JSON.parse(fs.readFileSync(networkPath, "utf8"));
  }
  return {};
};

const exportDeployments = () => {
  const networkPath = path.resolve(
    __dirname,
    `../deployments/${networkName}_latest.json`
  );

  const resetDeployments: boolean = argv.reset;

  if (!resetDeployments && fs.existsSync(networkPath)) {
    const currentTimestamp = new Date().getTime();
    fs.renameSync(
      networkPath,
      networkPath.replace("_latest.json", `_${currentTimestamp}.json`)
    );
  }

  if (resetDeployments && fs.existsSync(networkPath)) {
    fs.unlinkSync(networkPath);
  }

  fs.writeFileSync(networkPath, JSON.stringify(deployments, null, 2));
};

export {
  deployContract,
  declareContract,
  provider,
  deployer,
  loadExistingDeployments,
  exportDeployments,
  executeDeployCalls,
  resetDeployments,
};
