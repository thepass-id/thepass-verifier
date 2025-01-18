use core::starknet::{ContractAddress};
use integrity::{
    StarkProofWithSerde,
};

#[starknet::interface]
pub trait IVerifier<TContractState> {
    fn claim_pass(ref self: TContractState, stark_proof: StarkProofWithSerde, x: felt252) -> u256;
    fn set_cairo_verifier_contract(ref self: TContractState, cairo_verifier_contract: ContractAddress);
    fn set_pass_contract(ref self: TContractState, pass_contract: ContractAddress);
    fn pass_contract(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
pub mod Verifier {
    use core::num::traits::Zero;
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::starknet::{ContractAddress, get_caller_address};
    use crate::Pass::{IPassDispatcher, IPassDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    use super::{IVerifier};
    use integrity::{
        StarkProofWithSerde,
        settings::{VerifierSettings, FactHash, SecurityBits, HasherBitLength, StoneVersion},
    };
    use crate::CairoVerifier::{ICairoVerifierDispatcher, ICairoVerifierDispatcherTrait};
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
   
    #[storage]
    struct Storage {
        cairo_verifier_contract: ContractAddress,
        pass_contract: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PassClaimed: PassClaimed,
        ProofVerified: ProofVerified,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PassClaimed {
        #[key]
        pub account_id: ContractAddress,
        #[key]
        pub pass_id: u256,
        #[key]
        pub x: felt252
    }

    #[derive(Drop, Copy, Serde, starknet::Event)]
    pub struct ProofVerified {
        #[key]
        fact: FactHash,
        #[key]
        security_bits: SecurityBits,
        #[key]
        settings: VerifierSettings,
    }

    pub mod Errors {
        pub const INVALID_ADDRESS: felt252 = 'Invalid address';
        pub const PASS_CONTRACT_ALREADY_SET: felt252 = 'Pass contract already set';
        pub const VERIFIER_CONTRACT_ALREADY_SET: felt252 = 'Verifier contract already set';
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl Verifier of IVerifier<ContractState> {
        fn claim_pass(ref self: ContractState, stark_proof: StarkProofWithSerde, x: felt252) -> u256 {
            let account_id = get_caller_address();

            let proofVerified = self._verify(stark_proof);

            let pass_dispatcher = IPassDispatcher { contract_address: self.pass_contract.read() };
            let pass_id = pass_dispatcher.mint(account_id, x);
            self.emit(PassClaimed { account_id, pass_id, x });

            self.emit(ProofVerified { fact: proofVerified.fact, security_bits: proofVerified.security_bits, settings: proofVerified.settings });

            pass_id
        }

        fn set_cairo_verifier_contract(ref self: ContractState, cairo_verifier_contract: ContractAddress) {
            self.ownable.assert_only_owner();

            assert(cairo_verifier_contract.is_non_zero(), Errors::INVALID_ADDRESS);
            assert(self.cairo_verifier_contract.read().is_zero(), Errors::VERIFIER_CONTRACT_ALREADY_SET);

            self.cairo_verifier_contract.write(cairo_verifier_contract);
        }

        fn set_pass_contract(ref self: ContractState, pass_contract: ContractAddress) {
            self.ownable.assert_only_owner();

            assert(pass_contract.is_non_zero(), Errors::INVALID_ADDRESS);
            assert(self.pass_contract.read().is_zero(), Errors::PASS_CONTRACT_ALREADY_SET);

            self.pass_contract.write(pass_contract);
        }

        fn pass_contract(self: @ContractState) -> ContractAddress {
            self.pass_contract.read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionTrait {
        fn _verify(self: @ContractState, stark_proof: StarkProofWithSerde) -> ProofVerified {
            let cairo_verifier_dispatcher = ICairoVerifierDispatcher { contract_address: self.cairo_verifier_contract.read() };
            let settings = VerifierSettings { memory_verification: 2, hasher_bit_length: HasherBitLength::Lsb160, stone_version: StoneVersion::Stone6 };
            let verifiedProof = cairo_verifier_dispatcher.verify_proof_full(settings, stark_proof.into());

            ProofVerified { fact: verifiedProof.fact, security_bits: verifiedProof.security_bits, settings: verifiedProof.settings }
        }
    }
}
