use core::starknet::{ContractAddress};

#[starknet::interface]
pub trait IVerifierDummy<TContractState> {
    /// Claims a pass by providing a proof and an additional parameter `x`.
    /// Emits a `PassClaimed` event if the proof is valid.
    /// 
    /// Parameters:
    /// - `proof`: A `felt252` value representing the proof.
    /// - `x`: A `felt252` value representing additional data.
    ///
    /// Returns:
    /// - A `u256` value representing the ID of the claimed pass.
    fn claim_pass(ref self: TContractState, proof: felt252, x: felt252) -> u256;

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
pub mod VerifierDummy {
    // Use statements for external crates and modules.
    use core::num::traits::Zero;
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::starknet::{ContractAddress, get_caller_address};
    use crate::Pass::{IPassDispatcher, IPassDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    use super::IVerifierDummy;

    // Defines the ownable component for this contract.
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
   
    #[storage]
    struct Storage {
        cairo_verifier_contract: ContractAddress, // Address of the verifier contract.
        pass_contract: ContractAddress,           // Address of the pass contract.
        proof: felt252,                           // Proof value for verification.
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,       // Ownable component storage.
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        /// Event emitted when a pass is claimed.
        PassClaimed: PassClaimed,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PassClaimed {
        /// Address of the account claiming the pass.
        pub account_id: ContractAddress,
        /// ID of the claimed pass.
        pub pass_id: u256,
        /// Additional data associated with the pass claim.
        pub x: felt252
    }

    pub mod Errors {
        /// Error for an invalid address.
        pub const INVALID_ADDRESS: felt252 = 'Invalid address';
        /// Error when the pass contract is already set.
        pub const PASS_CONTRACT_ALREADY_SET: felt252 = 'Pass contract already set';
        /// Error for an invalid proof.
        pub const INVALID_PROOF: felt252 = 'Invalid proof';
    }

    #[constructor]
    /// Constructor function to initialize the contract.
    /// Sets the owner and the initial proof value.
    ///
    /// Parameters:
    /// - `owner`: The initial owner of the contract.
    /// - `proof`: The initial proof value.
    fn constructor(ref self: ContractState, owner: ContractAddress, proof: felt252,) {
        self.ownable.initializer(owner);
        self.proof.write(proof);
    }

    #[abi(embed_v0)]
    impl VerifierDummy of IVerifierDummy<ContractState> {
        fn claim_pass(ref self: ContractState, proof: felt252, x: felt252) -> u256 {
            let account_id = get_caller_address();

            // Ensure the provided proof is valid.
            assert(self._verify(proof) == true, Errors::INVALID_PROOF);

            // Mint a pass and emit a PassClaimed event.
            let pass_dispatcher = IPassDispatcher { contract_address: self.pass_contract.read() };
            let pass_id = pass_dispatcher.mint(account_id, x);
            self.emit(PassClaimed { account_id, pass_id, x });

            pass_id
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
        fn _verify(self: @ContractState, proof: felt252) -> bool {
            // Verify if the provided proof matches the stored proof.
            self.proof.read() == proof
        }
    }
}
