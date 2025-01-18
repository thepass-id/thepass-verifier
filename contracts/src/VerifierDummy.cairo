use core::starknet::{ContractAddress};

#[starknet::interface]
pub trait IVerifierDummy<TContractState> {
    fn claim_pass(ref self: TContractState, proof: felt252, x: felt252) -> u256;
    fn set_pass_contract(ref self: TContractState, pass_contract: ContractAddress);
    fn pass_contract(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
pub mod VerifierDummy {
    use core::num::traits::Zero;
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::starknet::{ContractAddress, get_caller_address};
    use crate::Pass::{IPassDispatcher, IPassDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    use super::IVerifierDummy;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
   
    #[storage]
    struct Storage {
        cairo_verifier_contract: ContractAddress,
        pass_contract: ContractAddress,
        proof: felt252,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PassClaimed: PassClaimed,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PassClaimed {
        pub account_id: ContractAddress,
        pub pass_id: u256,
        pub x: felt252
    }

    pub mod Errors {
        pub const INVALID_ADDRESS: felt252 = 'Invalid address';
        pub const PASS_CONTRACT_ALREADY_SET: felt252 = 'Pass contract already set';
        pub const INVALID_PROOF: felt252 = 'Invalid proof';
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, proof: felt252,) {
        self.ownable.initializer(owner);
        self.proof.write(proof);
    }

    #[abi(embed_v0)]
    impl VerifierDummy of IVerifierDummy<ContractState> {
        fn claim_pass(ref self: ContractState, proof: felt252, x: felt252) -> u256 {
            let account_id = get_caller_address();

            assert(self._verify(proof) == true, Errors::INVALID_PROOF);

            let pass_dispatcher = IPassDispatcher { contract_address: self.pass_contract.read() };
            let pass_id = pass_dispatcher.mint(account_id, x);
            self.emit(PassClaimed { account_id, pass_id, x });

            pass_id
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
        fn _verify(self: @ContractState, proof: felt252) -> bool {
            self.proof.read() == proof
        }
    }
}
