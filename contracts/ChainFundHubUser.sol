// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract ChainFundHubUser is AccessControl {
    bytes32 public constant CORE_ROLE = keccak256("CORE_ROLE");

    struct CampaignMedia {
        string mediaUri;
        string mediaType;
        bool isApproved;
    }

    struct CampaignUpdate {
        string content;
        uint256 timestamp;
        address author;
    }

    struct CampaignComment {
        address commenter;
        string content;
        uint256 timestamp;
    }

    mapping(uint256 => CampaignMedia[]) public campaignMedia;
    mapping(uint256 => string[]) public campaignTags;
    mapping(uint256 => CampaignUpdate[]) public campaignUpdates;
    mapping(uint256 => CampaignComment[]) public campaignComments;
    mapping(uint256 => bool) public featuredCampaigns;

    event MediaAdded(uint256 indexed campaignId, string mediaUri);
    event UpdateAdded(uint256 indexed campaignId, string content);
    event CommentAdded(uint256 indexed campaignId, address commenter);
    event CampaignFeatured(uint256 indexed campaignId);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function addCampaignMedia(
        uint256 _campaignId, 
        string memory _mediaUri,
        string memory _mediaType
    )  external onlyRole(CORE_ROLE) {
        require(bytes(_mediaUri).length > 0, "Media URI cannot be empty");
        require(
            keccak256(bytes(_mediaType)) == keccak256(bytes("image")) ||
            keccak256(bytes(_mediaType)) == keccak256(bytes("video")) ||
            keccak256(bytes(_mediaType)) == keccak256(bytes("document")),
            "Invalid media type"
    );

    CampaignMedia memory newMedia = CampaignMedia({
        mediaUri: _mediaUri,
        mediaType: _mediaType,
        isApproved: true
    });
    
    campaignMedia[_campaignId].push(newMedia);
    emit MediaAdded(_campaignId, _mediaUri);
}

    function addCampaignUpdate(
    uint256 _campaignId,
    string memory _content
) external onlyRole(CORE_ROLE) {
    require(bytes(_content).length > 0, "Content cannot be empty");
    require(bytes(_content).length <= 1000, "Content too long"); // Add reasonable limit

    CampaignUpdate memory update = CampaignUpdate({
        content: _content,
        timestamp: block.timestamp,
        author: tx.origin
    });
    
    campaignUpdates[_campaignId].push(update);
    emit UpdateAdded(_campaignId, _content);
}

function addComment(
    uint256 _campaignId,
    string memory _content
) external {
    require(bytes(_content).length > 0, "Comment cannot be empty");
    require(bytes(_content).length <= 500, "Comment too long"); // Add reasonable limit

    CampaignComment memory comment = CampaignComment({
        commenter: msg.sender,
        content: _content,
        timestamp: block.timestamp
    });
    
    campaignComments[_campaignId].push(comment);
    emit CommentAdded(_campaignId, msg.sender);
}

    function addTags(
    uint256 _campaignId,
    string[] memory _tags
) external onlyRole(CORE_ROLE) {
    require(_tags.length > 0, "No tags provided");
    require(_tags.length <= 5, "Too many tags"); // Limit number of tags

    for (uint i = 0; i < _tags.length; i++) {
        require(bytes(_tags[i]).length > 0, "Empty tag not allowed");
        require(bytes(_tags[i]).length <= 20, "Tag too long");
        campaignTags[_campaignId].push(_tags[i]);
    }
}

    function setFeatured(
        uint256 _campaignId, 
        bool _featured
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        featuredCampaigns[_campaignId] = _featured;
        if (_featured) {
            emit CampaignFeatured(_campaignId);
        }
    }

    function getCampaignMedia(uint256 _campaignId) 
        external 
        view 
        returns (CampaignMedia[] memory) 
    {
        return campaignMedia[_campaignId];
    }

    function getCampaignUpdates(uint256 _campaignId) 
        external 
        view 
        returns (CampaignUpdate[] memory) 
    {
        return campaignUpdates[_campaignId];
    }

    function getCampaignComments(uint256 _campaignId) 
        external 
        view 
        returns (CampaignComment[] memory) 
    {
        return campaignComments[_campaignId];
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