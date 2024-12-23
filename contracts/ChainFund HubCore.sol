// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

// Interface declarations
interface IChainFundHubFinance {
    function processDonation(uint256 campaignId, address donor) external payable;
    function withdrawFunds(uint256 campaignId, address recipient) external returns (bool);
    function issueRefund(uint256 campaignId, address donor) external;  
    function getDonationRefundStatus(uint256 campaignId, address donor) external view returns (bool[] memory);  
}

interface IChainFundHubCampaign {
    function createCampaign(string memory title, string memory description, uint256 target, uint256 duration) external returns (uint256);
    function updateCampaignStatus(uint256 campaignId, uint8 status) external;
    function fileComplaint(uint256 campaignId, string memory reason) external;  
    function checkExpiry(uint256 campaignId) external;  
    function getCampaignStatus(uint256 campaignId) external view returns (uint8);
    function updateRaisedAmount(uint256 campaignId, uint256 amount) external;
}

interface IChainFundHubUser {
    function addCampaignUpdate(uint256 campaignId, string memory content) external;
    function addCampaignMedia(uint256 campaignId, string memory mediaUri) external;
}

contract ChainFundHubCore is AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CAMPAIGN_MANAGER_ROLE = keccak256("CAMPAIGN_MANAGER_ROLE");
    bytes32 public constant FINANCE_ROLE = keccak256("FINANCE_ROLE");

    IChainFundHubFinance public financeManager;
    IChainFundHubCampaign public campaignManager;
    IChainFundHubUser public userManager;

    event ContractAddressUpdated(string contractName, address newAddress);
    event CoreFunctionExecuted(string functionName, address caller);
    event DonationProcessed(uint256 indexed campaignId, address donor, uint256 amount);
    event RefundProcessed(uint256 indexed campaignId, address donor);
    event ComplaintFiled(uint256 indexed campaignId, address complainant, string reason);

    constructor() Pausable() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }


     function donateToCampaign(uint256 _campaignId) external payable whenNotPaused {
        require(address(financeManager) != address(0), "Finance manager not set");
        require(address(campaignManager) != address(0), "Campaign manager not set");
        require(msg.value > 0, "Donation amount must be greater than 0");

        // Process the donation through finance manager
        financeManager.processDonation{value: msg.value}(_campaignId, msg.sender);

        campaignManager.updateRaisedAmount(_campaignId, msg.value);

        emit DonationProcessed(_campaignId, msg.sender, msg.value);
    }

    // function to request refund
    function requestRefund(uint256 _campaignId) external whenNotPaused {
        require(address(financeManager) != address(0), "Finance manager not set");
        require(address(campaignManager) != address(0), "Campaign manager not set");

        // Issue refund through finance manager
        financeManager.issueRefund(_campaignId, msg.sender);
        
        emit RefundProcessed(_campaignId, msg.sender);
    }

    //  complaint handling
    function fileCampaignComplaint(
        uint256 _campaignId,
        string memory _reason
    ) external whenNotPaused {
        require(address(campaignManager) != address(0), "Campaign manager not set");
        require(bytes(_reason).length > 0, "Reason cannot be empty");

       // Add this line to actually file the complaint
       campaignManager.fileComplaint(_campaignId, _reason); 
       
        emit ComplaintFiled(_campaignId, msg.sender, _reason);
    }

    // function to check campaign expiry
    function checkCampaignExpiry(uint256 _campaignId) external whenNotPaused {
        require(address(campaignManager) != address(0), "Campaign manager not set");
        
        // Call campaign manager to check expiry
        campaignManager.checkExpiry(_campaignId);
    }

    function setFinanceManager(address _financeManager) external onlyRole(ADMIN_ROLE) {
        financeManager = IChainFundHubFinance(_financeManager);
        emit ContractAddressUpdated("FinanceManager", _financeManager);
    }

    function setCampaignManager(address _campaignManager) external onlyRole(ADMIN_ROLE) {
        campaignManager = IChainFundHubCampaign(_campaignManager);
        emit ContractAddressUpdated("CampaignManager", _campaignManager);
    }

    function setUserManager(address _userManager) external onlyRole(ADMIN_ROLE) {
        userManager = IChainFundHubUser(_userManager);
        emit ContractAddressUpdated("UserManager", _userManager);
    }

    function pausePlatform() external onlyRole(ADMIN_ROLE) {
        _pause();
        emit CoreFunctionExecuted("pausePlatform", msg.sender);
    }

    function unpausePlatform() external onlyRole(ADMIN_ROLE) {
        _unpause();
        emit CoreFunctionExecuted("unpausePlatform", msg.sender);
    }

    function addCampaignManager(address account) external onlyRole(ADMIN_ROLE) {
        grantRole(CAMPAIGN_MANAGER_ROLE, account);
    }

    function removeCampaignManager(address account) external onlyRole(ADMIN_ROLE) {
        revokeRole(CAMPAIGN_MANAGER_ROLE, account);
    }

    function createCampaignWithDetails(
        string memory title,
        string memory description,
        uint256 target,
        uint256 duration,
        string memory mediaUri
    ) external whenNotPaused returns (uint256) {
        require(address(campaignManager) != address(0), "Campaign manager not set");
        require(address(userManager) != address(0), "User manager not set");
        require(bytes(title).length >= 3, "Title too short");
        require(bytes(description).length >= 10, "Description too short");
        require(target > 0, "Target amount must be greater than 0");
        require(duration >= 1 days && duration <= 365 days, "Duration must be between 1 and 365 days");
        require(bytes(mediaUri).length > 0, "Media URI cannot be empty");

        uint256 campaignId = campaignManager.createCampaign(
            title, 
            description, 
            target, 
            duration
        );

        userManager.addCampaignMedia(campaignId, mediaUri);

        emit CoreFunctionExecuted("createCampaignWithDetails", msg.sender);
        return campaignId;
    }

    receive() external payable {
        // Handle direct ETH transfers
    }

    function emergencyWithdraw() external onlyRole(ADMIN_ROLE) {
        require(address(this).balance > 0, "No funds to withdraw");
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
        emit CoreFunctionExecuted("emergencyWithdraw", msg.sender);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}