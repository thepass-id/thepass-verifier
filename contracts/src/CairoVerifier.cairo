use integrity::{
    StarkProofWithSerde,
    settings::{VerifierSettings, FactHash, JobId, SecurityBits},
};

#[derive(Drop, Copy, Serde, starknet::Event)]
pub struct ProofVerified {
    #[key]
    pub job_id: JobId,
    #[key]
    pub fact: FactHash,
    #[key]
    pub security_bits: SecurityBits,
    #[key]
    pub settings: VerifierSettings,
}

#[starknet::interface]
pub trait ICairoVerifier<TContractState> {
    /// Verifies a full proof using the provided verifier settings and serialized proof.
    ///
    /// Parameters:
    /// - `settings`: Configuration for the verifier.
    /// - `stark_proof_serde`: The proof in serialized form to be verified.
    ///
    /// Returns:
    /// - A `ProofVerified` event with the verification details.
    fn verify_proof_full(
        ref self: TContractState,
        settings: VerifierSettings,
        stark_proof_serde: StarkProofWithSerde,
    ) -> ProofVerified;
}

#[starknet::contract]
pub mod CairoVerifier {
    use starknet::{
        ContractAddress,
        storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map},
    };
    use integrity::{
        PublicInputImpl, StarkProofWithSerde,
        stark::{StarkProof, StarkProofImpl},
        settings::{VerifierSettings, JobId, FactHash, SecurityBits},
    };
    use core::hash::HashStateTrait;
    use core::poseidon::PoseidonTrait;
    use super::{ProofVerified, ICairoVerifier};

    #[storage]
    struct Storage {
        composition_contract_address: ContractAddress,
        oods_contract_address: ContractAddress,
        state_constant: Map<JobId, Option<felt252>>, // job_id => hash(constant state)
        state_variable: Map<JobId, Option<felt252>>, // job_id => hash(variable state)
        state_fact: Map<JobId, Option<FactHash>>, // job_id => fact_hash
        state_security_bits: Map<JobId, Option<SecurityBits>>, // job_id => security_bits
        state_settings: Map<JobId, Option<VerifierSettings>>, // job_id => verifier_settings
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        composition_contract_address: ContractAddress,
        oods_contract_address: ContractAddress
    ) {
        self.composition_contract_address.write(composition_contract_address);
        self.oods_contract_address.write(oods_contract_address);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ProofVerified: ProofVerified,
    }

    #[abi(embed_v0)]
    impl CairoVerifier of ICairoVerifier<ContractState> {
        fn verify_proof_full(
            ref self: ContractState,
            settings: VerifierSettings,
            stark_proof_serde: StarkProofWithSerde,
        ) -> ProofVerified {
            // Deserialize the proof from its serialized form.
            let stark_proof: StarkProof = stark_proof_serde.into();

            // Perform public input verification based on memory verification mode.
            let (program_hash, output_hash) = match settings.memory_verification {
                0 => stark_proof.public_input.verify_strict(), // Strict verification.
                1 => stark_proof.public_input.verify_relaxed(), // Relaxed verification.
                2 => stark_proof.public_input.verify_cairo1(), // Cairo1 verification.
                _ => {
                    // Handle invalid memory_verification value.
                    assert(false, 'invalid memory_verification');
                    (0, 0)
                }
            };

            // Verify the proof with the provided settings and contracts.
            let security_bits = stark_proof
                .verify(
                    self.composition_contract_address.read(),
                    self.oods_contract_address.read(),
                    @settings
                );

            // Compute the fact hash using Poseidon hashing of the program and output hashes.
            let fact = PoseidonTrait::new().update(program_hash).update(output_hash).finalize();

            // Create a `ProofVerified` event with the verification results.
            let event = ProofVerified { job_id: 0, fact, security_bits, settings };
            self.emit(event);

            event
        }
    }
}
