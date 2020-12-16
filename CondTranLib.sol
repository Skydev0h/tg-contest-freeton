pragma solidity >=0.6.0;

struct Constraints {
    uint64 minTons;
    uint64 maxTons;
    uint64 minAccepted;
    bool   nanoTons;
    int40  collectDeadline;
    int40  releaseLocktime;
    int40  releaseDeadline;
}

struct Flags {
    bool autoRelease;
    bool continuousColl;
}

struct Beneficiary {
    address addr;
    int64   value; // >0: ton, <0: -%
}

library Errors {
    uint8 constant NO_CONTROLLER     = 91;
    uint8 constant INVALID_SENDER    = 92;
    uint8 constant INVALID_KEY       = 93;
    uint8 constant BAD_MESSAGE_TYPE  = 94;
    uint8 constant BROKEN_CONTROLLER = 95;
    uint8 constant EXT_MSG_ONLY      = 96;

    uint8 constant INT_MSG_ONLY      = 97;
    uint8 constant NO_PUB_KEY        = 98;
    uint8 constant WRONG_PUB_KEY     = 99;

    uint8 constant COLLECT_DEADLINE_NOT_REACHED    = 101;
    uint8 constant RELEASE_LOCKTIME_NOT_REACHED    = 102;
    uint8 constant RELEASE_DEADLINE_ALREADY_PASSED = 103;
    uint8 constant CONTRACT_IN_RECLAIM_STATE       = 104;
    uint8 constant CONTRACT_BALANCE_TOO_LOW        = 105;
    uint8 constant GAS_RESERVE_LOW                 = 106;
}

library MsgFlag {
    uint8 constant AddTranFees  = 1;
    uint8 constant IgnoreErrors = 2;
    uint8 constant MsgBalance   = 64;
    uint8 constant AllBalance   = 128;
}