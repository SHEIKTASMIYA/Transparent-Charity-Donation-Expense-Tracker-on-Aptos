module charity_donation::charity_system {
    use std::string::String;
    use std::signer;
    use std::timestamp;
    use std::event;
    use std::vector;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::account;
    
    const E_NOT_INITIALIZED: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;
    const E_INVALID_AMOUNT: u64 = 3;
    const E_NOT_AUTHORIZED: u64 = 4;
    const E_ALREADY_INITIALIZED: u64 = 5;
    
    struct DonationEvent has drop, store {
        donor: address,
        charity: address,
        amount: u64,
        timestamp: u64,
    }

    struct SpendingEvent has drop, store {
        charity: address,
        resource_supplier: address,
        amount: u64,
        purpose: String,
        timestamp: u64,
    }

    struct WithdrawalEvent has drop, store {
        charity: address,
        amount: u64,
        timestamp: u64,
    }

    struct CharitySystem has key {
        charity_address: address,
        total_donations: u64,
        total_spent: u64,
        is_active: bool,
    }

    struct DonationRecord has key {
        donations: vector<DonationEntry>,
        spending_records: vector<SpendingEntry>,
    }

    struct DonationEntry has store {
        donor: address,
        amount: u64,
        timestamp: u64,
    }

    struct SpendingEntry has store {
        resource_supplier: address,
        amount: u64,
        purpose: String,
        timestamp: u64,
    }

    struct CharityEvents has key {
        donation_events: event::EventHandle<DonationEvent>,
        spending_events: event::EventHandle<SpendingEvent>,
        withdrawal_events: event::EventHandle<WithdrawalEvent>,
    }

    public entry fun initialize(
        account: &signer,
        charity_address: address
    ) {
        let account_addr = signer::address_of(account);
        
        assert!(account_addr == charity_address, E_NOT_AUTHORIZED);
        
        assert!(!exists<CharitySystem>(charity_address), E_ALREADY_INITIALIZED);

        let charity_system = CharitySystem {
            charity_address,
            total_donations: 0,
            total_spent: 0,
            is_active: true,
        };

        let donation_record = DonationRecord {
            donations: vector::empty<DonationEntry>(),
            spending_records: vector::empty<SpendingEntry>(),
        };

        let charity_events = CharityEvents {
            donation_events: account::new_event_handle<DonationEvent>(account),
            spending_events: account::new_event_handle<SpendingEvent>(account),
            withdrawal_events: account::new_event_handle<WithdrawalEvent>(account),
        };

        move_to(account, charity_system);
        move_to(account, donation_record);
        move_to(account, charity_events);
    }

    public entry fun donate(
        donor: &signer,
        charity_address: address,
        amount: u64
    ) acquires CharitySystem, DonationRecord, CharityEvents {
        assert!(amount > 0, E_INVALID_AMOUNT);
        assert!(exists<CharitySystem>(charity_address), E_NOT_INITIALIZED);

        let donor_addr = signer::address_of(donor);
        
        let donor_balance = coin::balance<AptosCoin>(donor_addr);
        assert!(donor_balance >= amount, E_INSUFFICIENT_BALANCE);

        coin::transfer<AptosCoin>(donor, charity_address, amount);

        let charity_system = borrow_global_mut<CharitySystem>(charity_address);
        charity_system.total_donations = charity_system.total_donations + amount;

        let donation_record = borrow_global_mut<DonationRecord>(charity_address);
        let donation_entry = DonationEntry {
            donor: donor_addr,
            amount,
            timestamp: timestamp::now_microseconds(),
        };
        vector::push_back(&mut donation_record.donations, donation_entry);

        let charity_events = borrow_global_mut<CharityEvents>(charity_address);
        event::emit_event(&mut charity_events.donation_events, DonationEvent {
            donor: donor_addr,
            charity: charity_address,
            amount,
            timestamp: timestamp::now_microseconds(),
        });
    }

    public entry fun spend_to_supplier(
        charity: &signer,
        resource_supplier: address,
        amount: u64,
        purpose: String
    ) acquires CharitySystem, DonationRecord, CharityEvents {
        let charity_addr = signer::address_of(charity);
        assert!(exists<CharitySystem>(charity_addr), E_NOT_INITIALIZED);
        assert!(amount > 0, E_INVALID_AMOUNT);

        let charity_balance = coin::balance<AptosCoin>(charity_addr);
        assert!(charity_balance >= amount, E_INSUFFICIENT_BALANCE);

        coin::transfer<AptosCoin>(charity, resource_supplier, amount);

        let charity_system = borrow_global_mut<CharitySystem>(charity_addr);
        charity_system.total_spent = charity_system.total_spent + amount;

        let donation_record = borrow_global_mut<DonationRecord>(charity_addr);
        let spending_entry = SpendingEntry {
            resource_supplier,
            amount,
            purpose,
            timestamp: timestamp::now_microseconds(),
        };
        vector::push_back(&mut donation_record.spending_records, spending_entry);

        let charity_events = borrow_global_mut<CharityEvents>(charity_addr);
        event::emit_event(&mut charity_events.spending_events, SpendingEvent {
            charity: charity_addr,
            resource_supplier,
            amount,
            purpose,
            timestamp: timestamp::now_microseconds(),
        });
    }

    #[view]
    public fun get_charity_info(charity_address: address): (u64, u64, bool) acquires CharitySystem {
        assert!(exists<CharitySystem>(charity_address), E_NOT_INITIALIZED);
        let charity_system = borrow_global<CharitySystem>(charity_address);
        (charity_system.total_donations, charity_system.total_spent, charity_system.is_active)
    }

    #[view]
    public fun get_donation_count(charity_address: address): u64 acquires DonationRecord {
        assert!(exists<DonationRecord>(charity_address), E_NOT_INITIALIZED);
        let donation_record = borrow_global<DonationRecord>(charity_address);
        vector::length(&donation_record.donations)
    }

    #[view]
    public fun get_spending_count(charity_address: address): u64 acquires DonationRecord {
        assert!(exists<DonationRecord>(charity_address), E_NOT_INITIALIZED);
        let donation_record = borrow_global<DonationRecord>(charity_address);
        vector::length(&donation_record.spending_records)
    }

}
