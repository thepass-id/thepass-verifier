import {
  deployContract,
  executeDeployCalls,
  exportDeployments,
  deployer,
} from "./deploy-contract";
import { green } from "./helpers/colorize-log";

const deployScript = async (): Promise<void> => {
  /*const { address: cairoVerifierAddress } = await deployContract({
    contract: "CairoVerifier",
    constructorArgs: {
      composition_contract_address: '0',
      oods_contract_address: '0',
    },
  });*/

  const { address: verifierAddress } = await deployContract({
    contract: "Verifier",
    constructorArgs: {
      owner: deployer.address,
    },
  });

  /*const { address: verifierDummyAddress } = await deployContract({
    contract: "VerifierDummy",
    constructorArgs: {
      owner: deployer.address,
      proof: 'valid_proof',
    },
  });

  */
  const { address: passAddress } = await deployContract({
    contract: "Pass",
    constructorArgs: {
      owner: verifierAddress,
      base_uri: "https://thepass-stg.onrender.com/pass",
    },
  });
};

deployScript()
  .then(async () => {
    executeDeployCalls()
      .then(() => {
        exportDeployments();
        console.log(green("All Setup Done"));
      })
      .catch((e) => {
        console.error(e);
        process.exit(1);
      });
  })
  .catch(console.error);
