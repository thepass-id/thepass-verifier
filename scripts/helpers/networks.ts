import { RpcProvider, Account } from "starknet";
import path from "path";
import dotenv from "dotenv";
import { Networks } from "../types";

dotenv.config({ path: path.resolve(__dirname, "../../.env") });

// devnet
const PRIVATE_KEY_DEVNET =
  process.env.PRIVATE_KEY_DEVNET || "0x564104eda6342ba54f2a698c0342b22b";
const RPC_URL_DEVNET = process.env.RPC_URL_DEVNET || "http://127.0.0.1:5050";
const ACCOUNT_ADDRESS_DEVNET =
  process.env.ACCOUNT_ADDRESS_DEVNET ||
  "0x6e1665171388ee560b46a9c321446734fefd29e9c94f969d6ecd0ca21db26aa";

const providerDevnet =
  RPC_URL_DEVNET && new RpcProvider({ nodeUrl: RPC_URL_DEVNET });
const deployerDevnet =
  ACCOUNT_ADDRESS_DEVNET &&
  PRIVATE_KEY_DEVNET &&
  new Account(providerDevnet, ACCOUNT_ADDRESS_DEVNET, PRIVATE_KEY_DEVNET, "1");

const ETH_TOKEN_ADDRESS_DEVNET =
  "0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7";
const STRK_TOKEN_ADDRESS_DEVNET =
  "0x4718F5A0FC34CC1AF16A1CDEE98FFB20C31F5CD61D6AB07201858F4287C938D";

// sepolia
const providerSepolia =
  process.env.RPC_URL_SEPOLIA &&
  new RpcProvider({ nodeUrl: process.env.RPC_URL_SEPOLIA });
const deployerSepolia =
  process.env.ACCOUNT_ADDRESS_SEPOLIA &&
  process.env.PRIVATE_KEY_SEPOLIA &&
  new Account(
    providerSepolia,
    process.env.ACCOUNT_ADDRESS_SEPOLIA,
    process.env.PRIVATE_KEY_SEPOLIA,
    "1"
  );

const ETH_TOKEN_ADDRESS =
  "0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7";
const STRK_TOKEN_ADDRESS =
  "0x4718F5A0FC34CC1AF16A1CDEE98FFB20C31F5CD61D6AB07201858F4287C938D";

// mainnet
const providerMainnet =
  process.env.RPC_URL_MAINNET &&
  new RpcProvider({ nodeUrl: process.env.RPC_URL_MAINNET });
const deployerMainnet =
  process.env.ACCOUNT_ADDRESS_MAINNET &&
  process.env.PRIVATE_KEY_MAINNET &&
  new Account(
    providerMainnet,
    process.env.ACCOUNT_ADDRESS_MAINNET,
    process.env.PRIVATE_KEY_MAINNET,
    "1"
  );

const feeTokenOptions = {
  devnet: [
    { name: "eth", address: ETH_TOKEN_ADDRESS_DEVNET },
    { name: "strk", address: STRK_TOKEN_ADDRESS_DEVNET },
  ],
  mainnet: [
    { name: "eth", address: ETH_TOKEN_ADDRESS },
    { name: "strk", address: STRK_TOKEN_ADDRESS },
  ],
  sepolia: [
    { name: "eth", address: ETH_TOKEN_ADDRESS },
    { name: "strk", address: STRK_TOKEN_ADDRESS },
  ],
};

export const networks: Networks = {
  devnet: {
    provider: providerDevnet,
    deployer: deployerDevnet,
    feeToken: feeTokenOptions.devnet,
  },
  sepolia: {
    provider: providerSepolia,
    deployer: deployerSepolia,
    feeToken: feeTokenOptions.sepolia,
  },
  mainnet: {
    provider: providerMainnet,
    deployer: deployerMainnet,
    feeToken: feeTokenOptions.mainnet,
  },
};
