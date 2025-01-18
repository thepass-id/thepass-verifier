use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::constants::{CALLER, OWNER, ZERO};

use openzeppelin_testing::{declare_and_deploy};
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, spy_events, EventSpy, EventSpyTrait,
    EventSpyAssertionsTrait, DeclareResultTrait
};
use starknet::{ContractAddress};
use thepass::Pass::IPassDispatcher;
use thepass::Pass::IPassDispatcherTrait;
use thepass::VerifierDummy::IVerifierDummyDispatcher;
use thepass::VerifierDummy::IVerifierDummyDispatcherTrait;
use thepass::VerifierDummy::VerifierDummy::{PassClaimed};
use thepass::VerifierDummy::VerifierDummy;

fn deploy_pass(verifier_address: ContractAddress) -> ContractAddress {
    let contract = declare("Pass").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append_serde(verifier_address);
    let base_uri: ByteArray = "https://api.example.com/pass/";
    calldata.append_serde(base_uri);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

fn setup_verifier_with_event() -> (EventSpy, IVerifierDummyDispatcher, ContractAddress) {
    let mut calldata = array![];
    calldata.append_serde(OWNER());
    calldata.append_serde('valid_proof');

    let spy = spy_events();
    let verifier_address = declare_and_deploy("VerifierDummy", calldata);
    let verifier = IVerifierDummyDispatcher { contract_address: verifier_address };

    let pass_address = deploy_pass(verifier_address);

    start_cheat_caller_address(verifier_address, OWNER());
    verifier.set_pass_contract(pass_address);

    (spy, verifier, pass_address)
}

fn setup_verifier() -> (EventSpy, IVerifierDummyDispatcher, ContractAddress) {
    let (mut spy, verifier, pass_address) = setup_verifier_with_event();

    // Drop all events
    let events = spy.get_events().events;
    spy._event_offset += events.len();

    (spy, verifier, pass_address)
}

#[test]
fn test_constructor() {
    let (_, verifier, pass_contract) = setup_verifier_with_event();

    assert_eq!(verifier.pass_contract(), pass_contract);
}

#[test]
fn test_claim_pass() {
    let (mut spy, verifier, pass_contract) = setup_verifier_with_event();
    let caller = CALLER();

    start_cheat_caller_address(verifier.contract_address, caller);
    start_cheat_caller_address(pass_contract, verifier.contract_address);

    let x = 1;
    let pass_id = verifier.claim_pass('valid_proof', x);

    assert_eq!(pass_id, 1);

    // Сheck deploy event
    let expected_event = VerifierDummy::Event::PassClaimed(
        PassClaimed { account_id: caller, pass_id: pass_id, x: x }
    );
    spy.assert_emitted(@array![(verifier.contract_address, expected_event)]);

    // Check deployment
    let pass = IPassDispatcher { contract_address: pass_contract };
    let tokens_of_owner = pass.get_tokens_of_owner(caller);
    let mut token_ids = array![];
    token_ids.append(1);
    assert_eq!(tokens_of_owner, token_ids);
}

#[test]
#[should_panic(expected: ('Invalid proof',))]
fn test_claim_pass_invalid_proof() {
    let (_, verifier, pass_contract) = setup_verifier_with_event();
    let caller = CALLER();

    start_cheat_caller_address(verifier.contract_address, caller);
    start_cheat_caller_address(pass_contract, verifier.contract_address);

    let x = 1;
    verifier.claim_pass('invalid_proof', x);
}

#[test]
#[should_panic(expected: ('ERC721: invalid receiver',))]
fn test_claim_pass_invalid_receiver() {
    let (_, verifier, _) = setup_verifier_with_event();

    // Start acting as pass contract
    start_cheat_caller_address(verifier.contract_address, ZERO());

    let x = 1;
    verifier.claim_pass('valid_proof', x);
}

#[test]
fn test_claim_pass_receiver() {
    let (_, verifier, _) = setup_verifier_with_event();

    // Start acting as pass contract
    start_cheat_caller_address(verifier.contract_address, CALLER());

    let x = 1;
    let pass_id = verifier.claim_pass('valid_proof', x);
    assert_eq!(pass_id, 1);
}

#[test]
fn test_set_pass_contract() {
    let mut calldata = array![];
    calldata.append_serde(OWNER());
    calldata.append_serde('valid_proof');

    let verifier_address = declare_and_deploy("VerifierDummy", calldata);
    let verifier = IVerifierDummyDispatcher { contract_address: verifier_address };

    let pass_address = deploy_pass(verifier_address);

    start_cheat_caller_address(verifier_address, OWNER());
    verifier.set_pass_contract(pass_address);
}

#[test]
#[should_panic(expected: ('Pass contract already set',))]
fn test_set_pass_contract_already_set() {
    let (_, verifier, pass_contract) = setup_verifier_with_event();

    start_cheat_caller_address(verifier.contract_address, OWNER());
    verifier.set_pass_contract(pass_contract);
}

#[test]
fn test_pass_contract() {
    let (_, verifier, pass_address) = setup_verifier();

    assert_eq!(verifier.pass_contract(), pass_address);
}
