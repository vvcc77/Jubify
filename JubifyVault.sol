// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/*
    JUBIFY MVP Vault / Coordinator
    - Custodia un ERC20 (ej. USDC en Avalanche)
    - Registra plan de ahorro
    - Ejecuta retiro programado
    - Aplica proof-of-life + herencia + fondo social
    - Permite registrar rebalanceos decididos off-chain

    NOTA:
    - Los nombres de beneficiarios y metadata rica deben vivir off-chain.
    - Este contrato guarda direcciones y porcentajes, no "bank accounts".
*/

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract JubifyVault is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // =========================
    // Roles
    // =========================
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // =========================
    // Strategy IDs de ejemplo
    // =========================
    bytes32 public constant STRATEGY_CONSERVATIVE = keccak256("CONSERVATIVE");
    bytes32 public constant STRATEGY_BALANCED = keccak256("BALANCED");
    bytes32 public constant STRATEGY_GROWTH = keccak256("GROWTH");

    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_BENEFICIARIES = 5;

    IERC20 public immutable asset;
    address public socialFundTreasury;

    enum PlanStatus {
        None,
        Active,
        Paused
    }

    enum Frequency {
        None,
        Weekly,
        Monthly,
        Quarterly
    }

    struct SavingsPlan {
        PlanStatus status;
        uint128 contributionAmount;     // monto esperado por aporte
        Frequency contributionFrequency; // frecuencia esperada de aporte
        bytes32 strategyId;             // estrategia elegida
        uint64 createdAt;
        uint64 lastContributionAt;
    }

    struct RetirementConfig {
        bool enabled;
        uint64 lockUntil;               // no se paga antes de esta fecha
        Frequency releaseFrequency;     // frecuencia de liberación
        uint128 releaseAmount;          // monto por liberación
        uint64 lastReleaseAt;
    }

    struct ProtectionConfig {
        bool protectionEnabled;
        bool inheritanceEnabled;
        uint64 proofOfLifeInterval;     // segundos
        uint64 lastProofOfLifeAt;
        uint16 socialFundBps;           // comisión al fondo social al ejecutar herencia
    }

    struct Beneficiary {
        address account;                // destino on-chain
        uint16 bps;                     // porcentaje sobre el remanente distributable
    }

    error ZeroAddress();
    error InvalidAmount();
    error InvalidStatus();
    error InvalidFrequency();
    error InvalidStrategy();
    error PlanDoesNotExist();
    error PlanNotActive();
    error RetirementNotReady();
    error ProtectionNotEnabled();
    error InheritanceNotEnabled();
    error ProofOfLifeStillValid();
    error InvalidBeneficiaries();
    error NothingToPay();
    error UnauthorizedStateChange();

    event PlanConfigured(
        address indexed user,
        uint128 contributionAmount,
        Frequency contributionFrequency,
        bytes32 indexed strategyId,
        PlanStatus status
    );

    event PlanStatusUpdated(address indexed user, PlanStatus newStatus);

    event ContributionRegistered(
        address indexed user,
        uint256 amount,
        uint256 newBalance
    );

    event RetirementConfigured(
        address indexed user,
        uint64 lockUntil,
        Frequency releaseFrequency,
        uint128 releaseAmount
    );

    event ProtectionConfigured(
        address indexed user,
        bool protectionEnabled,
        bool inheritanceEnabled,
        uint64 proofOfLifeInterval,
        uint16 socialFundBps
    );

    event BeneficiariesUpdated(address indexed user);
    event ProofOfLifeUpdated(address indexed user, uint64 timestamp);

    event ScheduledPayoutExecuted(
        address indexed user,
        uint256 amountPaid,
        uint256 remainingBalance
    );

    event InheritanceExecuted(
        address indexed user,
        uint256 totalAmount,
        uint256 socialFundAmount
    );

    event RebalanceRecorded(
        address indexed user,
        bytes32 indexed oldStrategyId,
        bytes32 indexed newStrategyId,
        bytes32 reasonHash
    );

    event StrategyAllowanceUpdated(bytes32 indexed strategyId, bool allowed);
    event SocialFundTreasuryUpdated(address indexed newTreasury);

    mapping(address => SavingsPlan) public plans;
    mapping(address => RetirementConfig) public retirements;
    mapping(address => ProtectionConfig) public protections;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public totalContributed;

    mapping(bytes32 => bool) public allowedStrategies;
    mapping(address => Beneficiary[]) private _beneficiaries;

    constructor(
        address asset_,
        address admin_,
        address operator_,
        address socialFundTreasury_
    ) {
        if (asset_ == address(0) || admin_ == address(0) || operator_ == address(0) || socialFundTreasury_ == address(0)) {
            revert ZeroAddress();
        }

        asset = IERC20(asset_);
        socialFundTreasury = socialFundTreasury_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(OPERATOR_ROLE, operator_);
        _grantRole(PAUSER_ROLE, admin_);

        // allowlist inicial de estrategias
        allowedStrategies[STRATEGY_CONSERVATIVE] = true;
        allowedStrategies[STRATEGY_BALANCED] = true;
        allowedStrategies[STRATEGY_GROWTH] = true;

        emit StrategyAllowanceUpdated(STRATEGY_CONSERVATIVE, true);
        emit StrategyAllowanceUpdated(STRATEGY_BALANCED, true);
        emit StrategyAllowanceUpdated(STRATEGY_GROWTH, true);
        emit SocialFundTreasuryUpdated(socialFundTreasury_);
    }

    // =========================
    // Admin
    // =========================

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setSocialFundTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();
        socialFundTreasury = newTreasury;
        emit SocialFundTreasuryUpdated(newTreasury);
    }

    function setAllowedStrategy(bytes32 strategyId, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (strategyId == bytes32(0)) revert InvalidStrategy();
        allowedStrategies[strategyId] = allowed;
        emit StrategyAllowanceUpdated(strategyId, allowed);
    }

    // =========================
    // User plan / onboarding on-chain
    // =========================

    function configurePlan(
        uint128 contributionAmount,
        Frequency contributionFrequency,
        bytes32 strategyId
    ) external whenNotPaused {
        if (contributionAmount == 0) revert InvalidAmount();
        if (contributionFrequency == Frequency.None) revert InvalidFrequency();
        if (!allowedStrategies[strategyId]) revert InvalidStrategy();

        SavingsPlan storage p = plans[msg.sender];

        if (p.createdAt == 0) {
            p.createdAt = uint64(block.timestamp);
        }

        p.status = PlanStatus.Active;
        p.contributionAmount = contributionAmount;
        p.contributionFrequency = contributionFrequency;
        p.strategyId = strategyId;

        emit PlanConfigured(
            msg.sender,
            contributionAmount,
            contributionFrequency,
            strategyId,
            p.status
        );
    }

    function setPlanStatus(PlanStatus newStatus) external whenNotPaused {
        SavingsPlan storage p = plans[msg.sender];
        if (p.createdAt == 0) revert PlanDoesNotExist();
        if (newStatus == PlanStatus.None) revert InvalidStatus();

        p.status = newStatus;
        emit PlanStatusUpdated(msg.sender, newStatus);
    }

    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();

        SavingsPlan storage p = plans[msg.sender];
        if (p.createdAt == 0) revert PlanDoesNotExist();
        if (p.status != PlanStatus.Active) revert PlanNotActive();

        asset.safeTransferFrom(msg.sender, address(this), amount);

        balances[msg.sender] += amount;
        totalContributed[msg.sender] += amount;
        p.lastContributionAt = uint64(block.timestamp);

        emit ContributionRegistered(msg.sender, amount, balances[msg.sender]);
    }

    // =========================
    // Retirement
    // =========================

    function configureRetirement(
        uint64 lockUntil,
        Frequency releaseFrequency,
        uint128 releaseAmount
    ) external whenNotPaused {
        SavingsPlan storage p = plans[msg.sender];
        if (p.createdAt == 0) revert PlanDoesNotExist();
        if (releaseFrequency == Frequency.None) revert InvalidFrequency();
        if (releaseAmount == 0) revert InvalidAmount();
        if (lockUntil <= block.timestamp) revert RetirementNotReady();

        retirements[msg.sender] = RetirementConfig({
            enabled: true,
            lockUntil: lockUntil,
            releaseFrequency: releaseFrequency,
            releaseAmount: releaseAmount,
            lastReleaseAt: 0
        });

        emit RetirementConfigured(msg.sender, lockUntil, releaseFrequency, releaseAmount);
    }

    function executeScheduledPayout(address user)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 amountPaid)
    {
        SavingsPlan storage p = plans[user];
        if (p.createdAt == 0) revert PlanDoesNotExist();

        RetirementConfig storage r = retirements[user];
        if (!r.enabled) revert RetirementNotReady();
        if (block.timestamp < r.lockUntil) revert RetirementNotReady();
        if (!_isReleaseDue(r)) revert RetirementNotReady();
        if (balances[user] == 0) revert NothingToPay();

        amountPaid = _min(uint256(r.releaseAmount), balances[user]);
        balances[user] -= amountPaid;
        r.lastReleaseAt = uint64(block.timestamp);

        asset.safeTransfer(user, amountPaid);

        emit ScheduledPayoutExecuted(user, amountPaid, balances[user]);
    }

    function previewNextPayoutAt(address user) external view returns (uint256) {
        RetirementConfig memory r = retirements[user];
        if (!r.enabled) return 0;

        if (block.timestamp < r.lockUntil) {
            return r.lockUntil;
        }

        if (r.lastReleaseAt == 0) {
            return r.lockUntil;
        }

        return uint256(r.lastReleaseAt) + _frequencyToSeconds(r.releaseFrequency);
    }

    // =========================
    // Protection / Inheritance
    // =========================

    function configureProtection(
        bool protectionEnabled,
        bool inheritanceEnabled,
        uint64 proofOfLifeInterval,
        uint16 socialFundBps
    ) external whenNotPaused {
        SavingsPlan storage p = plans[msg.sender];
        if (p.createdAt == 0) revert PlanDoesNotExist();
        if (socialFundBps > BPS_DENOMINATOR) revert InvalidBeneficiaries();

        if (inheritanceEnabled && proofOfLifeInterval == 0) {
            revert InvalidAmount();
        }

        protections[msg.sender] = ProtectionConfig({
            protectionEnabled: protectionEnabled,
            inheritanceEnabled: inheritanceEnabled,
            proofOfLifeInterval: proofOfLifeInterval,
            lastProofOfLifeAt: uint64(block.timestamp),
            socialFundBps: socialFundBps
        });

        emit ProtectionConfigured(
            msg.sender,
            protectionEnabled,
            inheritanceEnabled,
            proofOfLifeInterval,
            socialFundBps
        );
    }

    function setBeneficiaries(Beneficiary[] calldata items) external whenNotPaused {
        SavingsPlan storage p = plans[msg.sender];
        if (p.createdAt == 0) revert PlanDoesNotExist();
        if (items.length == 0 || items.length > MAX_BENEFICIARIES) revert InvalidBeneficiaries();

        uint256 totalBps = 0;

        delete _beneficiaries[msg.sender];

        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].account == address(0) || items[i].bps == 0) {
                revert InvalidBeneficiaries();
            }

            totalBps += items[i].bps;
            _beneficiaries[msg.sender].push(items[i]);
        }

        if (totalBps != BPS_DENOMINATOR) revert InvalidBeneficiaries();

        emit BeneficiariesUpdated(msg.sender);
    }

    function pingProofOfLife() external whenNotPaused {
        ProtectionConfig storage cfg = protections[msg.sender];
        if (!cfg.protectionEnabled && !cfg.inheritanceEnabled) revert ProtectionNotEnabled();

        cfg.lastProofOfLifeAt = uint64(block.timestamp);
        emit ProofOfLifeUpdated(msg.sender, cfg.lastProofOfLifeAt);
    }

    function isInheritanceTriggerable(address user) public view returns (bool) {
        ProtectionConfig memory cfg = protections[user];

        if (!cfg.inheritanceEnabled) return false;
        if (cfg.proofOfLifeInterval == 0) return false;
        if (cfg.lastProofOfLifeAt == 0) return false;

        return block.timestamp > uint256(cfg.lastProofOfLifeAt) + uint256(cfg.proofOfLifeInterval);
    }

    function triggerInheritance(address user)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 socialFundAmount)
    {
        SavingsPlan storage p = plans[user];
        if (p.createdAt == 0) revert PlanDoesNotExist();

        ProtectionConfig storage cfg = protections[user];
        if (!cfg.inheritanceEnabled) revert InheritanceNotEnabled();
        if (!isInheritanceTriggerable(user)) revert ProofOfLifeStillValid();

        uint256 amount = balances[user];
        if (amount == 0) revert NothingToPay();

        Beneficiary[] storage list = _beneficiaries[user];
        if (list.length == 0) revert InvalidBeneficiaries();

        balances[user] = 0;

        // Desactiva la posición para evitar doble ejecución.
        p.status = PlanStatus.Paused;
        retirements[user].enabled = false;
        cfg.protectionEnabled = false;
        cfg.inheritanceEnabled = false;

        socialFundAmount = (amount * cfg.socialFundBps) / BPS_DENOMINATOR;
        uint256 distributable = amount - socialFundAmount;

        if (socialFundAmount > 0) {
            asset.safeTransfer(socialFundTreasury, socialFundAmount);
        }

        uint256 totalSent = 0;

        for (uint256 i = 0; i < list.length; i++) {
            uint256 payout = (distributable * list[i].bps) / BPS_DENOMINATOR;
            totalSent += payout;
            asset.safeTransfer(list[i].account, payout);
        }

        // Envía el dust al primer beneficiario para evitar remanentes mínimos.
        uint256 dust = distributable - totalSent;
        if (dust > 0) {
            asset.safeTransfer(list[0].account, dust);
        }

        emit InheritanceExecuted(user, amount, socialFundAmount);
    }

    // =========================
    // Rebalance / Operator actions
    // =========================

    function recordRebalance(
        address user,
        bytes32 newStrategyId,
        bytes32 reasonHash
    ) external onlyRole(OPERATOR_ROLE) whenNotPaused {
        SavingsPlan storage p = plans[user];
        if (p.createdAt == 0) revert PlanDoesNotExist();
        if (!allowedStrategies[newStrategyId]) revert InvalidStrategy();

        bytes32 oldStrategyId = p.strategyId;
        p.strategyId = newStrategyId;

        emit RebalanceRecorded(user, oldStrategyId, newStrategyId, reasonHash);
    }

    // =========================
    // Views
    // =========================

    function getBeneficiaries(address user) external view returns (Beneficiary[] memory result) {
        Beneficiary[] storage src = _beneficiaries[user];
        result = new Beneficiary[](src.length);

        for (uint256 i = 0; i < src.length; i++) {
            result[i] = src[i];
        }
    }

    function isReleaseDue(address user) external view returns (bool) {
        RetirementConfig memory r = retirements[user];
        if (!r.enabled) return false;
        if (block.timestamp < r.lockUntil) return false;
        return _isReleaseDue(r);
    }

    // =========================
    // Internal
    // =========================

    function _isReleaseDue(RetirementConfig memory r) internal view returns (bool) {
        if (r.releaseFrequency == Frequency.None) return false;

        if (r.lastReleaseAt == 0) {
            return block.timestamp >= r.lockUntil;
        }

        return block.timestamp >= uint256(r.lastReleaseAt) + _frequencyToSeconds(r.releaseFrequency);
    }

    function _frequencyToSeconds(Frequency f) internal pure returns (uint256) {
        if (f == Frequency.Weekly) return 7 days;
        if (f == Frequency.Monthly) return 30 days;
        if (f == Frequency.Quarterly) return 90 days;
        revert InvalidFrequency();
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}