use core::starknet::{ContractAddress};
use integrity::{StarkProofWithSerde};

#[starknet::interface]
pub trait IVerifier<TContractState> {
    /// Claims a pass by providing a STARK proof and an additional parameter `x`.
    /// Emits `PassClaimed` and `ProofVerified` events if the proof is valid.
    ///
    /// Parameters:
    /// - `stark_proof`: A `StarkProofWithSerde` object representing the STARK proof.
    /// - `x`: A `felt252` value representing additional data.
    ///
    /// Returns:
    /// - A `u256` value representing the ID of the claimed pass.
    fn claim_pass(ref self: TContractState, stark_proof: StarkProofWithSerde, x: felt252) -> u256;

    /// Sets the address of the Cairo verifier contract.
    /// Can only be called by the owner.
    ///
    /// Parameters:
    /// - `cairo_verifier_contract`: A `ContractAddress` value representing the address of the Cairo verifier contract.
    fn set_cairo_verifier_contract(ref self: TContractState, cairo_verifier_contract: ContractAddress);

    /// Sets the address of the pass contract.
    /// Can only be called by the owner.
    ///
    /// Parameters:
    /// - `pass_contract`: A `ContractAddress` value representing the address of the pass contract.
    fn set_pass_contract(ref self: TContractState, pass_contract: ContractAddress);

    /// Retrieves the address of the currently set pass contract.
    ///
    /// Returns:
    /// - A `ContractAddress` value representing the address of the pass contract.
    fn pass_contract(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
pub mod Verifier {
    // Use statements for external crates and modules.
    use core::num::traits::Zero;
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::starknet::{ContractAddress, get_caller_address};
    use crate::Pass::{IPassDispatcher, IPassDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    use super::{IVerifier};
    use integrity::{StarkProofWithSerde, settings::{VerifierSettings, FactHash, SecurityBits, HasherBitLength, StoneVersion}};
    use crate::CairoVerifier::{ICairoVerifierDispatcher, ICairoVerifierDispatcherTrait};
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
   
    #[storage]
    struct Storage {
        cairo_verifier_contract: ContractAddress, // Address of the Cairo verifier contract.
        pass_contract: ContractAddress,           // Address of the pass contract.
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,       // Ownable component storage.
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        /// Event emitted when a pass is claimed.
        PassClaimed: PassClaimed,
        /// Event emitted when a proof is verified.
        ProofVerified: ProofVerified,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PassClaimed {
        /// Address of the account claiming the pass.
        #[key]
        pub account_id: ContractAddress,
        /// ID of the claimed pass.
        #[key]
        pub pass_id: u256,
        /// Additional data associated with the pass claim.
        #[key]
        pub x: felt252
    }

    #[derive(Drop, Copy, Serde, starknet::Event)]
    pub struct ProofVerified {
        /// Hash of the verified fact.
        #[key]
        fact: FactHash,
        /// Security bits used for the proof.
        #[key]
        security_bits: SecurityBits,
        /// Settings used for the verifier.
        #[key]
        settings: VerifierSettings,
    }

    pub mod Errors {
        /// Error for an invalid address.
        pub const INVALID_ADDRESS: felt252 = 'Invalid address';
        /// Error when the pass contract is already set.
        pub const PASS_CONTRACT_ALREADY_SET: felt252 = 'Pass contract already set';
        /// Error when the verifier contract is already set.
        pub const VERIFIER_CONTRACT_ALREADY_SET: felt252 = 'Verifier contract already set';
    }

    #[constructor]
    /// Constructor function to initialize the contract.
    /// Sets the owner of the contract.
    ///
    /// Parameters:
    /// - `owner`: The initial owner of the contract.
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl Verifier of IVerifier<ContractState> {
        fn claim_pass(ref self: ContractState, stark_proof: StarkProofWithSerde, x: felt252) -> u256 {
            let account_id = get_caller_address();

            // Verify the provided proof.
            let proofVerified = self._verify(stark_proof);

            // Mint a pass and emit PassClaimed and ProofVerified events.
            let pass_dispatcher = IPassDispatcher { contract_address: self.pass_contract.read() };
            let pass_id = pass_dispatcher.mint(account_id, x);
            self.emit(PassClaimed { account_id, pass_id, x });
            self.emit(ProofVerified { fact: proofVerified.fact, security_bits: proofVerified.security_bits, settings: proofVerified.settings });

            pass_id
        }

        fn set_cairo_verifier_contract(ref self: ContractState, cairo_verifier_contract: ContractAddress) {
            self.ownable.assert_only_owner();

            // Ensure the Cairo verifier contract address is valid and not already set.
            assert(cairo_verifier_contract.is_non_zero(), Errors::INVALID_ADDRESS);
            assert(self.cairo_verifier_contract.read().is_zero(), Errors::VERIFIER_CONTRACT_ALREADY_SET);

            // Set the Cairo verifier contract address.
            self.cairo_verifier_contract.write(cairo_verifier_contract);
        }

        fn set_pass_contract(ref self: ContractState, pass_contract: ContractAddress) {
            self.ownable.assert_only_owner();

            // Ensure the pass contract address is valid and not already set.
            assert(pass_contract.is_non_zero(), Errors::INVALID_ADDRESS);
            assert(self.pass_contract.read().is_zero(), Errors::PASS_CONTRACT_ALREADY_SET);

            // Set the pass contract address.
            self.pass_contract.write(pass_contract);
        }

        fn pass_contract(self: @ContractState) -> ContractAddress {
            // Read and return the pass contract address.
            self.pass_contract.read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionTrait {
        fn _verify(self: @ContractState, stark_proof: StarkProofWithSerde) -> ProofVerified {
            // Verify the provided proof using the Cairo verifier contract.
            let cairo_verifier_dispatcher = ICairoVerifierDispatcher { contract_address: self.cairo_verifier_contract.read() };
            let settings = VerifierSettings { memory_verification: 2, hasher_bit_length: HasherBitLength::Lsb160, stone_version: StoneVersion::Stone6 };
            let verifiedProof = cairo_verifier_dispatcher.verify_proof_full(settings, stark_proof.into());

            // Return the verified proof details.
            ProofVerified { fact: verifiedProof.fact, security_bits: verifiedProof.security_bits, settings: verifiedProof.settings }
        }
    }
}
