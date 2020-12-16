pragma solidity >=0.6.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

import "CondTranLib.sol";

/// @title Conditional Transfer smart contract (CTSC)
/// @author Skydev0h at GitHub
contract CondTran {

    // Initially i used VarUInt16, but I do not see such here
    // UInt64 will be good upto 18,446,744,073.709551616 ton
    // As of now there are       5,016,494,730 crystals
    // As the number is slowly growing, I consider UI64 safe
    uint64 min_tons; // <- min_grams
    uint64 max_tons; // <- max_grams
    uint64 min_accepted;

    // BL:UnixTime = 32
    uint32 collect_deadline;
    uint32 release_locktime;
    uint32 release_deadline;

    uint64 constant DefaultGasReserve = 1 ton;

    // BL:Flags = 6, but cant use less than UInt8
    // uint8 Flags;
    bool f_auto_release;
    bool f_continuous_coll;
    // State
    bool f_can_reclaim;
    bool f_initialized;
    bool f_destroyed;

    // cell investors
    mapping(address => uint64) investors;

    // cell beneficiaries
    Beneficiary[] beneficiaries;
    address ultimate_beneficiary;

    // addr_none if no controller
    // addr_std for internal controller (contains address)
    // addr_extern for external controller (contains pubkey)
    address controller_addr;

    // ************************************************************************

    event FundsReleased(uint128 balance);
    event ReclaimStarted(uint128 balance);

    event FundsAutoReleased(uint128 balance);
    event ReclaimAutoStarted(uint128 balance);

    // ************************************************************************

    // Storage is handled by compiler, those are not needed anymore
    // tuple Storage:Load() inline_ref
    // () Storage:Save(tuple data) impure inline_ref

    // This is handled by compiler too
    // () Message:Send(int wc, int addr, int grams, int mode) impure inline_ref

    // ************************************************************************

    function Logic_DoRelease() private {
        require(!f_can_reclaim, Errors.CONTRACT_IN_RECLAIM_STATE);
        tvm.accept();
        f_destroyed = true;
        // tvm.commit();
        uint128 bal = address(this).balance - msg.value;
        uint128 rem = bal;
        for (uint i = 0; i < beneficiaries.length; i++) {
            // address addr; uint64 value; // >0: ton, <0: -%
            int64 val = beneficiaries[i].value;
            if (val == 0) continue;
            uint128 value = val > 0 ? uint128(val) : 0;
            // 9,223,372,036,854,775,808
            // High pct: 100,000,000,000
            if (val < -200000000) {
                continue; // Invalid
            } else if (val < -100000000) {
                // Percentage of *remaining*
                value = rem * uint128(-int(val)-100000000) / 100000000;
            } else if (val < 0) {
                // Percentage of *total*
                value = bal * uint128(-val) / 100000000;
            }
            uint128 to_send = math.min(value, rem);
            if (to_send > 0) {
                beneficiaries[i].addr.transfer({value: to_send, bounce: false, flag: MsgFlag.IgnoreErrors});
                // tvm.commit();
                if (rem >= to_send)
                    rem -= to_send;
                else
                    break;
            }
        }
        delete investors;
        delete beneficiaries;
        ultimate_beneficiary.transfer({value: 0, bounce: false, flag: MsgFlag.AllBalance + MsgFlag.IgnoreErrors});
    }

    // ************************************************************************

    function verifyController() private view {
        uint8 controller_type = controller_addr.getType();
        require(controller_type != 0, Errors.NO_CONTROLLER);
        require(now >= collect_deadline, Errors.COLLECT_DEADLINE_NOT_REACHED);
        require(now >= release_locktime, Errors.RELEASE_LOCKTIME_NOT_REACHED);
        require((release_deadline == 0) || (now <= release_deadline),
                Errors.RELEASE_DEADLINE_ALREADY_PASSED);
        if (controller_type == 1) { // External
            // Verify signature
            require(msg.sender == address(0), Errors.EXT_MSG_ONLY);
            require(msg.pubkey() == controller_addr.value, Errors.INVALID_KEY);
            tvm.accept();
        } else if (controller_type == 2) { // Internal
            // Verify address
            require(msg.sender == controller_addr, Errors.INVALID_SENDER);
        } else
            revert(Errors.BROKEN_CONTROLLER);
        if (msg.sender.getType() == 2)
            msg.sender.transfer({value: 0, bounce: false, flag: MsgFlag.MsgBalance});
    }

    function Controller_ReleaseFunds() public {
        verifyController();
        require(!f_can_reclaim, Errors.CONTRACT_IN_RECLAIM_STATE);
        require(address(this).balance - msg.value >= min_tons, Errors.CONTRACT_BALANCE_TOO_LOW);
        emit FundsReleased(address(this).balance - msg.value);
        Logic_DoRelease();
    }

    function Controller_InitiateReclaim() public {
        verifyController();
        f_can_reclaim = true;
        delete beneficiaries;
        emit ReclaimStarted(address(this).balance - msg.value);
    }

    // ************************************************************************

    function ReserveMoreGas(uint64 gasReserve) public {
        require(msg.sender.getType() == 2, Errors.INT_MSG_ONLY);
        require(gasReserve >= DefaultGasReserve, Errors.GAS_RESERVE_LOW);
        processMessage(gasReserve);
    }

    function sendMessage(address dest, uint128 value, uint16 flag, string message) private pure {
        TvmBuilder b;
        b.store(uint32(0));
        TvmBuilder s;
        s.store(message);
        b.store(s.toCell());
        dest.transfer({value: value, bounce: false, flag: flag, body: b.toCell()});
    }

    function reply(uint128 value, string message) private inline pure {
        sendMessage(msg.sender, value, MsgFlag.MsgBalance, message);
    }

    function processMessage(uint64 gasReserve) private {
        if (f_destroyed) {
            tvm.accept();
            ultimate_beneficiary.transfer({value: 0, bounce: false, flag: MsgFlag.AllBalance});
            return;
        }

        uint128 bal = address(this).balance - msg.value;
        if ((!f_can_reclaim) && (collect_deadline > 0)
        && (now >= collect_deadline) && (bal < min_tons)) {
            // LOGIC: Process failing to collect min tons before collect deadline
            f_can_reclaim = true;
            delete beneficiaries;
            emit ReclaimAutoStarted(bal);
        }

        if (f_auto_release && (!f_can_reclaim) && (release_deadline > 0)
        && (now >= release_deadline) && (bal >= min_tons)) {
            // LOGIC: Automatically release money after release deadline
            reply(0, "Auto release");
            emit FundsAutoReleased(bal);
            Logic_DoRelease();
            return;
        }

        // Controller internal message logic is not needed anymore
        // All switching and processing is done automagically

        // ********************************************************************************
        // ********************************************************************************
        // Additional chat logic, remove when migrating to DeBot control
        // ********************************************************************************
        // But now I can add an interesting feature using strings
        uint8 controller_type = controller_addr.getType();
        if ((controller_type == 2) && (msg.sender == controller_addr)) {
            uint88 cmd = 0;
            TvmSlice slice = msg.data;
            (uint16 bits, uint8 refs) = slice.size();
            if ((bits == 32) && (refs == 1)) {
                uint32 op = slice.decode(uint32);
                if (op == 0) {
                    TvmSlice refSlice = slice.loadRefAsSlice();
                    (uint16 in_bits, uint8 in_refs) = refSlice.size();
                    if ((in_bits == 88) && (in_refs == 0)) {
                        cmd = refSlice.decode(uint88);
                    }
                }
            }
            if ((bits == 120) && (refs == 0)) {
                uint32 op = slice.decode(uint32);
                if (op == 0) {
                    cmd = slice.decode(uint88);
                }
            }
            if ((cmd == 0x436D643A52656C65617365) || (cmd == 0x436D643A5265636C61696D)) {
                //require(now >= collect_deadline, Errors.COLLECT_DEADLINE_NOT_REACHED);
                if (now < collect_deadline) {
                    reply(0, "Not yet coll deadline");
                    return;
                }
                //require(now >= release_locktime, Errors.RELEASE_LOCKTIME_NOT_REACHED);
                if (now < release_locktime) {
                    reply(0, "Not yet rel locktime");
                    return;
                }
                //require((release_deadline == 0) || (now <= release_deadline), Errors.RELEASE_DEADLINE_ALREADY_PASSED);
                if ((release_deadline != 0) && (now > release_deadline)) {
                    reply(0, "Rel deadline passed");
                    return;
                }
            }
            // Cmd:Release | 43 6D 64 3A 52 65 6C 65 61 73 65
            if (cmd == 0x436D643A52656C65617365) {
                //require(!f_can_reclaim, Errors.CONTRACT_IN_RECLAIM_STATE);
                if (f_can_reclaim) {
                    reply(0, "Already reclaiming");
                    return;
                }
                //require(address(this).balance >= min_tons, Errors.CONTRACT_BALANCE_TOO_LOW);
                if (bal < min_tons) {
                    reply(0, "Target not reached");
                    return;
                }
                reply(0, "OK: Release");
                emit FundsReleased(bal);
                Logic_DoRelease();
                return;
            }
            // Cmd:Reclaim | 43 6D 64 3A 52 65 63 6C 61 69 6D
            if (cmd == 0x436D643A5265636C61696D) {
                if (f_can_reclaim) {
                    reply(0, "Already reclaiming");
                    return;
                }
                f_can_reclaim = true;
                delete beneficiaries;
                reply(0, "OK: Reclaim");
                emit ReclaimStarted(bal);
                return;
            }
        }
        // ********************************************************************************
        // ********************************************************************************

        if ((!f_auto_release) && (!f_can_reclaim)
        && (release_deadline > 0) && (now >= release_deadline)) {
            // LOGIC: Activate automatic reclaim after release deadline
            f_can_reclaim = true;
            delete beneficiaries;
            emit ReclaimAutoStarted(bal);
            tvm.commit();
        }

        if (f_can_reclaim) {
            // LOGIC: Process internal message in reclaim mode
            optional(uint64) optInvested = investors.fetch(msg.sender);
            if (!optInvested.hasValue()) {
                // msg.sender.transfer({value: 0, bounce: false, flag: MsgFlag.MsgBalance});
                reply(0, "Not invested");
                return;
            }
            delete investors[msg.sender];
            // msg.sender.transfer({value: optInvested.get(), bounce: false, flag: MsgFlag.MsgBalance});
            reply(optInvested.get(), "Reclaimed");
            return;
        }

        int deposit = msg.value - gasReserve;
        if (deposit < min_accepted) {
            // LOGIC: Check min accepted tons condition
            // msg.sender.transfer({value: 0, bounce: false, flag: MsgFlag.MsgBalance});
            reply(0, "Value is too low");
            return;
        }

        if ((collect_deadline != 0) && (now >= collect_deadline) && (!f_continuous_coll)) {
            // LOGIC: Prevent deposit if collect deadline reached and continuous collection disabled
            // msg.sender.transfer({value: 0, bounce: false, flag: MsgFlag.MsgBalance});
            reply(0, "Collect deadline passed");
            return;
        }

        if ((max_tons > 0) && (bal + deposit > max_tons)) {
            // LOGIC: Process max tons overflowing
            deposit = max_tons - bal;
            if (deposit <= min_accepted) {
                reply(0, "Contract is full");
                return;
            }
        }

        if (deposit <= 0) {
            // msg.sender.transfer({value: 0, bounce: false, flag: MsgFlag.MsgBalance});
            reply(0, "Need more ton for gas");
            return;
        }

        uint64 accnt = 0;
        optional(uint64) optInvested = investors.fetch(msg.sender);
        if (optInvested.hasValue())
            accnt = optInvested.get();

        investors[msg.sender] = uint64(accnt + deposit);

        tvm.rawReserve(uint(bal + deposit), 0);
        // msg.sender.transfer({value: 0, bounce: false, flag: MsgFlag.AllBalance});
        sendMessage(msg.sender, 0, MsgFlag.AllBalance, "Accepted");
    }

    // receive() external pure {}
    fallback() external {
        require(msg.sender.getType() == 2, Errors.INT_MSG_ONLY);
        processMessage(DefaultGasReserve);
    }

    // ************************************************************************

    // Some logic from () recv_external(slice in_msg) impure
    // + additional initialization logic
    // Data was pre-initialized in Fift in origin version
    constructor(
        Constraints constraints, Flags flags, Beneficiary[] beneficiariesList,
        address ultimateBeneficiary, address controllerAddr
    ) public
    {
        require(tvm.pubkey() != 0, Errors.NO_PUB_KEY);
        require(msg.pubkey() == tvm.pubkey(), Errors.WRONG_PUB_KEY);
        tvm.accept();
        uint64 multiplier = constraints.nanoTons ? 1 : 1000000000;
        min_tons = constraints.minTons * multiplier;
        max_tons = constraints.maxTons * multiplier;
        min_accepted = constraints.minAccepted * multiplier;
        collect_deadline = (constraints.collectDeadline >= 0)
                         ? uint32(constraints.collectDeadline)
                         : uint32(now - constraints.collectDeadline);
        release_locktime = (constraints.releaseLocktime >= 0)
                         ? uint32(constraints.releaseLocktime)
                         : uint32(now - constraints.releaseLocktime);
        release_deadline = (constraints.releaseDeadline >= 0)
                         ? uint32(constraints.releaseDeadline)
                         : uint32(now - constraints.releaseDeadline);
        f_auto_release = flags.autoRelease;
        f_continuous_coll = flags.continuousColl;
        f_can_reclaim = false; f_destroyed = false;
        beneficiaries = beneficiariesList;
        ultimate_beneficiary = ultimateBeneficiary;
        if (controllerAddr.getType() == 2) {
            if (controllerAddr.wid == -111) {
                controller_addr = address.makeAddrExtern(controllerAddr.value, 256);
            } else
                controller_addr = controllerAddr;
        } else
            controller_addr = controllerAddr;
        f_initialized = true;
    }

    // ************************************************************************
    // _ get_config() method_id

    function getInformation() public view returns (
        Constraints constraints, Flags flags,
        bool canReclaim, bool destroyed,
        Beneficiary[] beneficiariesList, address ultimateBeneficiary,
        mapping(address => uint64) investorsMap,
        address controller, uint8 controllerType
    ) {
        constraints.minTons = min_tons;
        constraints.maxTons = max_tons;
        constraints.minAccepted = min_accepted;
        constraints.nanoTons = true;
        constraints.collectDeadline = collect_deadline;
        constraints.releaseLocktime = release_locktime;
        constraints.releaseDeadline = release_deadline;
        flags.autoRelease = f_auto_release;
        flags.continuousColl = f_continuous_coll;
        canReclaim = f_can_reclaim;
        destroyed = f_destroyed;
        beneficiariesList = beneficiaries;
        ultimateBeneficiary = ultimate_beneficiary;
        investorsMap = investors;
        controller = controller_addr;
        controllerType = controller_addr.getType();
    }

    // ************************************************************************

    // int reclaiming() method_id {
    function getIsReclaiming() public view returns (bool) {
        return f_can_reclaim;
    }

    // int reclaimable(int workchain_id, int address) method_id
    function getReclaimable(address addr) public view returns (uint64) {
        if (!f_can_reclaim)
            return 0;
        // optional(StakeValue) optSourceStake = round.stakes.fetch(source);
        optional(uint64) optInvested = investors.fetch(addr);
        if (!optInvested.hasValue())
            return 0;
        return optInvested.get();
    }

    // ************************************************************************

    function getReleaseable() public view returns (
        mapping(address => uint128) toBens, uint128 toUltBen, address[] invalid
    ) {
        return getReleaseableEmulated(address(this).balance);
    }

    function getReleaseableEmulated(uint128 balance) public view returns (
        mapping(address => uint128) toBens, uint128 toUltBen, address[] invalid
    ) {
        uint128 bal = balance;
        uint128 rem = bal;
        for (uint i = 0; i < beneficiaries.length; i++) {
            // address addr; uint64 value; // >0: ton, <0: -%
            int64 val = beneficiaries[i].value;
            if (val == 0) continue;
            uint128 value = val > 0 ? uint128(val) : 0;
            // 9,223,372,036,854,775,808
            // High pct: 100,000,000,000
            if (val < -200000000) {
                invalid.push(beneficiaries[i].addr);
                continue; // Invalid
            } else if (val < -100000000) {
                // Percentage of *remaining*
                value = rem * uint128(-int(val) - 100000000) / 100000000;
            } else if (val < 0) {
                // Percentage of *total*
                value = bal * uint128(-val) / 100000000;
            }
            uint128 to_send = math.min(value, rem);
            if (to_send > 0) {
                toBens[beneficiaries[i].addr] += to_send;
                if (rem >= to_send)
                    rem -= to_send;
                else
                    break;
            }
        }
        toUltBen = rem;
    }

}