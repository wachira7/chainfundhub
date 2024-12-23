// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ChainFundHubFinance is AccessControl, ReentrancyGuard {
    bytes32 public constant CORE_ROLE = keccak256("CORE_ROLE");
    
    struct DonationInfo {
        uint256 amount;
        uint256 timestamp;
        address token;
         bool refunded;
    }

    struct WithdrawalLimit {
        uint256 dailyLimit;
        uint256 lastWithdrawal;
        uint256 withdrawnToday;
    }

    mapping(uint256 => mapping(address => DonationInfo[])) public donationHistory;
    mapping(uint256 => WithdrawalLimit) public withdrawalLimits;
    mapping(address => bool) public supportedTokens;
    mapping(uint256 => uint256) public totalRefunded;
    
    event DonationProcessed(uint256 indexed campaignId, address indexed donor, uint256 amount);
    event FundsWithdrawn(uint256 indexed campaignId, address indexed recipient, uint256 amount);
    event RefundIssued(uint256 indexed campaignId, address indexed donor, uint256 amount);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function processDonation(uint256 _campaignId, address _donor) 
        external 
        payable 
        onlyRole(CORE_ROLE) 
        nonReentrant 
    {
        require(msg.value > 0, "No donation amount provided");
        
        DonationInfo memory newDonation = DonationInfo({
            amount: msg.value,
            timestamp: block.timestamp,
            token: address(0), // ETH
            refunded: false    // Initialize as not refunded
        });
        
        donationHistory[_campaignId][_donor].push(newDonation);
        emit DonationProcessed(_campaignId, _donor, msg.value);
    }

    // Updated issueRefund function with better tracking
    function issueRefund(
        uint256 _campaignId, 
        address _donor
    ) external onlyRole(CORE_ROLE) nonReentrant {
        DonationInfo[] storage donations = donationHistory[_campaignId][_donor];
        require(donations.length > 0, "No donations found");

        uint256 totalRefund = 0;
        
        // Calculate refundable amount from non-refunded donations
        for (uint i = 0; i < donations.length; i++) {
            if (!donations[i].refunded && donations[i].token == address(0)) {
                totalRefund += donations[i].amount;
                donations[i].refunded = true;  // Mark as refunded
            }
        }

        require(totalRefund > 0, "No refundable amount");
        require(address(this).balance >= totalRefund, "Insufficient contract balance");

        totalRefunded[_campaignId] += totalRefund;  // Update total refunded

        (bool success, ) = payable(_donor).call{value: totalRefund}("");
        require(success, "Refund transfer failed");

        emit RefundIssued(_campaignId, _donor, totalRefund);
    }

    function getDonationRefundStatus(uint256 _campaignId, address _donor) 
        external 
        view 
        returns (bool[] memory) 
    {
        DonationInfo[] storage donations = donationHistory[_campaignId][_donor];
        bool[] memory refundStatuses = new bool[](donations.length);
        
        for (uint i = 0; i < donations.length; i++) {
            refundStatuses[i] = donations[i].refunded;
        }
        
        return refundStatuses;
    }

    // New function to get total refunded amount for a campaign
    function getTotalRefunded(uint256 _campaignId) external view returns (uint256) {
        return totalRefunded[_campaignId];
    }

    function setDailyWithdrawalLimit(
        uint256 _campaignId, 
        uint256 _limit
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        withdrawalLimits[_campaignId].dailyLimit = _limit;
    }

    function getDonationHistory(uint256 _campaignId, address _donor) 
        external 
        view 
        returns (DonationInfo[] memory) 
    {
        return donationHistory[_campaignId][_donor];
    }

    receive() external payable {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}