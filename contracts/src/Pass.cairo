use starknet::{ContractAddress};

#[starknet::interface]
pub trait IPass<TContractState> {
    fn mint(ref self: TContractState, account_id: ContractAddress, x: felt252) -> u256;
    fn get_tokens_of_owner(ref self: TContractState, account_id: ContractAddress) -> Array<u256>;
    // ERC721 overrides
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray;
}

#[starknet::contract]
pub mod Pass {
    use core::array::ArrayTrait;
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::ERC721Component::ERC721HooksTrait;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::extensions::erc721_enumerable::ERC721EnumerableComponent;
    use starknet::storage::{Map, StoragePathEntry};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress};
    use super::{IPass};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(
        path: ERC721EnumerableComponent, storage: erc721_enumerable, event: ERC721EnumerableEvent
    );
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721EnumerableImpl =
        ERC721EnumerableComponent::ERC721EnumerableImpl<ContractState>;
    impl ERC721EnumerableInternalImpl = ERC721EnumerableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721CamelOnlyImpl = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PassMinted: PassMinted,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        ERC721EnumerableEvent: ERC721EnumerableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }
    #[derive(Drop, starknet::Event)]
    pub struct PassMinted {
        pub account_id: ContractAddress,
        pub x: felt252
    }

    #[storage]
    struct Storage {
        passes: Map<u256, PassAttributes>,
        account_owned_passes: Map<
            ContractAddress, Map<felt252, bool>
        >, // account_id -> x -> is_owned
        last_token_id: u256,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        pub erc721_enumerable: ERC721EnumerableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[derive(Debug, Drop, Serde, starknet::Store)]
    pub struct PassAttributes {
        account_id: ContractAddress,
        x: felt252,
    }

    pub mod Errors {
        pub const PASS_ALREADY_MINTED: felt252 = 'Pass already minted';
        pub const TRANSFER_NOT_ALLOWED: felt252 = 'Transfer is not allowed';
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, base_uri: ByteArray) {
        self.erc721.initializer("Pass", "PASS", base_uri);
        self.erc721_enumerable.initializer();
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl PassImpl of IPass<ContractState> {
        fn mint(ref self: ContractState, account_id: ContractAddress, x: felt252) -> u256 {
            self.ownable.assert_only_owner();

            assert(
                self.account_owned_passes.entry(account_id).entry(x).read() == false,
                Errors::PASS_ALREADY_MINTED
            );

            let new_token_id = self.last_token_id.read() + 1;
            self.last_token_id.write(new_token_id);
            self.erc721.mint(account_id, new_token_id);

            let pass_attributes = PassAttributes { account_id, x, };

            self.passes.entry(new_token_id).write(pass_attributes);
            self.account_owned_passes.entry(account_id).entry(x).write(true);
            self.emit(PassMinted { account_id, x });

            new_token_id
        }

        fn get_tokens_of_owner(ref self: ContractState, account_id: ContractAddress) -> Array<u256> {
            let balance = self.erc721.balance_of(account_id);

            let mut tokens_of_owner = array![];

            if balance.is_zero() {
                return tokens_of_owner;
            }

            for i in 0
                ..balance {
                    let token_id = self.erc721_enumerable.token_of_owner_by_index(account_id, i);
                    tokens_of_owner.append(token_id);
                };

            tokens_of_owner
        }

        fn name(self: @ContractState) -> ByteArray {
            self.erc721.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc721.symbol()
        }

        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.erc721.token_uri(token_id)
        }
    }

    impl ERC721HooksImpl of ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.erc721_enumerable.before_update(to, token_id);

            // Don't allow updates not from zero address (i.e. only mints)
            // Self-burns are disallowed by ERC721 spec
            let from = self._owner_of(token_id);
            assert(from.is_zero(), Errors::TRANSFER_NOT_ALLOWED);
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {}
    }
}
