use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::constants::{OWNER, ZERO};

use openzeppelin_testing::{declare_and_deploy};
use openzeppelin_token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, spy_events,
    EventSpy, EventSpyAssertionsTrait, DeclareResultTrait
};
use starknet::{ContractAddress, contract_address_const};
use thepass::Pass::IPassDispatcher;
use thepass::Pass::IPassDispatcherTrait;
use thepass::Pass::Pass::{PassMinted};
use thepass::Pass::Pass;
use thepass::VerifierDummy::IVerifierDummyDispatcher;
use thepass::VerifierDummy::IVerifierDummyDispatcherTrait;

fn USER() -> ContractAddress {
    contract_address_const::<'USER'>()
}

fn USER2() -> ContractAddress {
    contract_address_const::<'USER2'>()
}

// Token IDs
const TOKEN_1: u256 = 1;
const TOKEN_2: u256 = 2;
const TOKEN_3: u256 = 3;
const TOKEN_4: u256 = 4;
const TOKEN_5: u256 = 5;

const TOKENS_LEN: u256 = 5;

fn deploy_pass(verifier_address: ContractAddress) -> ContractAddress {
    let contract = declare("Pass").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append_serde(verifier_address);
    let base_uri: ByteArray = "https://api.example.com/pass/";
    calldata.append_serde(base_uri);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

fn deploy_verifier() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(OWNER());
    calldata.append_serde('valid_proof');

    let verifier_address = declare_and_deploy("VerifierDummy", calldata);
    let verifier = IVerifierDummyDispatcher { contract_address: verifier_address };

    let pass_address = deploy_pass(verifier_address);

    start_cheat_caller_address(verifier_address, OWNER());
    verifier.set_pass_contract(pass_address);

    verifier_address
}

fn setup_pass_with_event() -> (EventSpy, IPassDispatcher, ContractAddress) {
    let verifier_address = deploy_verifier();
    let pass_address = deploy_pass(verifier_address);
    let pass_contract = IPassDispatcher { contract_address: pass_address };

    let spy = spy_events();
    (spy, pass_contract, verifier_address,)
}

#[test]
fn test_deployment() {
    let verifier_address = deploy_verifier();
    let pass_address = deploy_pass(verifier_address);
    let dispatcher = ERC721ABIDispatcher { contract_address: pass_address };

    assert(dispatcher.name() == "Pass", 'Wrong name');
    assert(dispatcher.symbol() == "PASS", 'Wrong symbol');
}


#[test]
fn test_minting() {
    let (mut spy, pass, verifier_address) = setup_pass_with_event();
    let pass_address = pass.contract_address;
    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: pass_address
    };

    // Start acting as pass contract
    start_cheat_caller_address(pass_address, verifier_address);

    // Mint PASS - token ID will be number as u256 and x event_1
    pass.mint(USER(), 'event_1');

    // Сheck PASS minted event
    let expected_event = Pass::Event::PassMinted(PassMinted { account_id: USER(), x: 'event_1' });
    spy.assert_emitted(@array![(pass_address, expected_event)]);

    // Verify ownership
    let token_id: u256 = 1;
    assert(erc721_dispatcher.owner_of(token_id) == USER(), 'Wrong token owner');
    assert(erc721_dispatcher.balance_of(USER()) == 1, 'Wrong balance');
}

#[test]
#[should_panic(expected: ('ERC721: invalid receiver',))]
fn test_invalid_receiver() {
    let (_, pass, verifier_address) = setup_pass_with_event();
    let pass_address = pass.contract_address;

    // Start acting as pass contract
    start_cheat_caller_address(pass_address, verifier_address);

    // Mint PASS - token ID will be number as u256 and x event_1
    pass.mint(ZERO(), 'event_1');
}

#[test]
#[should_panic(expected: ('Pass already minted',))]
fn test_pass_already_minted() {
    let (_, pass, verifier_address) = setup_pass_with_event();
    let pass_address = pass.contract_address;
    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: pass_address
    };

    // Start acting as pass contract
    start_cheat_caller_address(pass_address, verifier_address);

    // Mint PASS - token ID will be number as u256 and x event_1
    pass.mint(USER(), 'event_1');

    // Verify ownership
    let token_id: u256 = 1;
    assert(erc721_dispatcher.owner_of(token_id) == USER(), 'Wrong token owner');

    // Mint pass again
    pass.mint(USER(), 'event_1');
}

#[test]
fn test_get_tokens_of_owner() {
    let (_, pass, verifier_address) = setup_pass_with_event();
    let pass_address = pass.contract_address;

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: pass_address
    };

    // Start acting as pass contract
    start_cheat_caller_address(pass_address, verifier_address);

    // Mint PASSs
    let token_id_1 = pass.mint(USER(), 'event_1');
    let token_id_2 = pass.mint(USER2(), 'event_1');
    let token_id_3 = pass.mint(USER(), 'event_2');

    assert(token_id_1 == 1, 'Wrong token id');
    assert(token_id_2 == 2, 'Wrong token id');
    assert(token_id_3 == 3, 'Wrong token id');

    // Verify ownership
    assert(erc721_dispatcher.balance_of(USER()) == 2, 'Wrong balance');
    assert(erc721_dispatcher.balance_of(USER2()) == 1, 'Wrong balance');
    assert_eq!(pass.get_tokens_of_owner(USER()), array![1, 3]);
    assert_eq!(pass.get_tokens_of_owner(USER2()), array![2]);
}

#[test]
#[should_panic(expected: ('Transfer is not allowed',))]
fn test_cant_transfer_pass() {
    let (_, pass, verifier_address) = setup_pass_with_event();
    let pass_address = pass.contract_address;

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: pass_address
    };

    // Start acting as pass contract
    start_cheat_caller_address(pass_address, verifier_address);

    // Mint PASS - token ID will be number as u256 and x event_1
    pass.mint(USER(), 'event1');

    // Try to transfer to USER2
    start_cheat_caller_address(pass_address, USER());
    let token_id: u256 = 1;
    erc721_dispatcher.transfer_from(USER(), USER2(), token_id);
}

#[test]
fn test_name() {
    let (_, pass, _) = setup_pass_with_event();
    let pass_address = pass.contract_address;

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: pass_address
    };

    assert_eq!(erc721_dispatcher.name(), "Pass");
}

#[test]
fn test_symbol() {
    let (_, pass, _) = setup_pass_with_event();
    let pass_address = pass.contract_address;

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: pass_address
    };

    assert_eq!(erc721_dispatcher.symbol(), "PASS");
}

#[test]
fn test_token_uri() {
    let (_, pass, verifier_address) = setup_pass_with_event();
    let pass_address = pass.contract_address;

    // Start acting as pass contract
    start_cheat_caller_address(pass_address, verifier_address);

    // Mint PASS - token ID will be number as u256 and x event_1
    pass.mint(USER(), 'event_1');

    let token_id: u256 = 1;
    assert_eq!(pass.token_uri(token_id), "https://api.example.com/pass/1");
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_token_uri_nonexistent() {
    let (_, pass, verifier_address) = setup_pass_with_event();
    let pass_address = pass.contract_address;

    // Start acting as pass contract
    start_cheat_caller_address(pass_address, verifier_address);

    // Mint PASS - token ID will be number as u256 and x event_1
    pass.mint(USER(), 'event_1');

    let invalid_token_id: u256 = 99999;

    // Try to get URI for non-existent token
    pass.token_uri(invalid_token_id);
}