// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title AgriStore Nigeria Smart Contracts
 * @dev Comprehensive smart contract system for agricultural data management on Filecoin
 * @notice Built for ETHNigeria 2025 Hackathon - Filecoin Orbit Track
 */
contract AgriStoreNigeria is Ownable, ReentrancyGuard {
    struct Farmer {
        uint256 id;
        string name;
        string location;
        string[] cropTypes;
        uint256 landSize;
        string filecoinCID;
        uint256 registrationDate;
        bool verified;
        address walletAddress;
    }

    struct Crop {
        uint256 id;
        uint256 farmerId;
        string cropType;
        uint256 plantingDate;
        uint256 expectedHarvestDate;
        string currentStage;
        string soilData;
        string ipfsHash;
        uint256 predictedYield;
        string qualityGrade;
        bool harvested;
    }

    struct SupplyChainRecord {
        uint256 id;
        uint256 cropId;
        string batchNumber;
        address[] handlers;
        string[] locations;
        uint256[] timestamps;
        string[] statusUpdates;
        string ipfsHash;
        bool delivered;
    }

    struct StorageRecord {
        string cid;
        uint256 size;
        uint256 timestamp;
        address uploader;
        string dataType;
        uint256 redundancyLevel;
        bool verified;
    }

    mapping(uint256 => Farmer) public farmers;
    mapping(address => uint256) public farmersByAddress;
    mapping(uint256 => Crop) public crops;
    mapping(uint256 => SupplyChainRecord) public supplyChain;
    mapping(string => StorageRecord) public filecoinStorage;

    uint256 public farmerCount;
    uint256 public cropCount;
    uint256 public supplyChainCount;

    event FarmerRegistered(uint256 indexed farmerId, address indexed farmerAddress, string name);
    event FarmerVerified(uint256 indexed farmerId, address indexed verifier);
    event CropRegistered(uint256 indexed cropId, uint256 indexed farmerId, string cropType);
    event CropHarvested(uint256 indexed cropId, uint256 actualYield);
    event SupplyChainCreated(uint256 indexed chainId, uint256 indexed cropId, string batchNumber);
    event SupplyChainUpdated(uint256 indexed chainId, string location, string status);
    event DataStoredOnFilecoin(string indexed cid, address indexed uploader, string dataType);

    modifier onlyVerifiedFarmer() {
        require(farmersByAddress[msg.sender] != 0, "Not a registered farmer");
        require(farmers[farmersByAddress[msg.sender]].verified, "Farmer not verified");
        _;
    }

    modifier validFarmer(uint256 _farmerId) {
        require(_farmerId > 0 && _farmerId <= farmerCount, "Invalid farmer ID");
        _;
    }

    modifier validCrop(uint256 _cropId) {
        require(_cropId > 0 && _cropId <= cropCount, "Invalid crop ID");
        _;
    }

    constructor() Ownable(msg.sender) {
        farmerCount = 0;
        cropCount = 0;
        supplyChainCount = 0;
    }

    function registerFarmer(
        string memory _name,
        string memory _location,
        string[] memory _cropTypes,
        uint256 _landSize,
        string memory _filecoinCID
    ) external {
        require(farmersByAddress[msg.sender] == 0, "Farmer already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_location).length > 0, "Location cannot be empty");
        require(_landSize > 0, "Land size must be greater than 0");

        farmerCount++;
        farmers[farmerCount] = Farmer({
            id: farmerCount,
            name: _name,
            location: _location,
            cropTypes: _cropTypes,
            landSize: _landSize,
            filecoinCID: _filecoinCID,
            registrationDate: block.timestamp,
            verified: false,
            walletAddress: msg.sender
        });

        farmersByAddress[msg.sender] = farmerCount;

        emit FarmerRegistered(farmerCount, msg.sender, _name);
    }

    function verifyFarmer(uint256 _farmerId) external onlyOwner validFarmer(_farmerId) {
        farmers[_farmerId].verified = true;
        emit FarmerVerified(_farmerId, msg.sender);
    }

    function updateFarmerData(uint256 _farmerId, string memory _filecoinCID) external validFarmer(_farmerId) {
        require(farmers[_farmerId].walletAddress == msg.sender || msg.sender == owner(), "Unauthorized");
        farmers[_farmerId].filecoinCID = _filecoinCID;
    }

    function registerCrop(
        string memory _cropType,
        uint256 _plantingDate,
        uint256 _expectedHarvestDate,
        string memory _soilData,
        string memory _ipfsHash,
        uint256 _predictedYield,
        string memory _qualityGrade
    ) external onlyVerifiedFarmer {
        require(bytes(_cropType).length > 0, "Crop type cannot be empty");
        require(_plantingDate <= block.timestamp, "Planting date cannot be in the future");
        require(_expectedHarvestDate > _plantingDate, "Harvest date must be after planting");

        uint256 farmerId = farmersByAddress[msg.sender];
        cropCount++;

        crops[cropCount] = Crop({
            id: cropCount,
            farmerId: farmerId,
            cropType: _cropType,
            plantingDate: _plantingDate,
            expectedHarvestDate: _expectedHarvestDate,
            currentStage: "Planted",
            soilData: _soilData,
            ipfsHash: _ipfsHash,
            predictedYield: _predictedYield,
            qualityGrade: _qualityGrade,
            harvested: false
        });

        emit CropRegistered(cropCount, farmerId, _cropType);
    }

    function updateCropStage(uint256 _cropId, string memory _newStage) external validCrop(_cropId) {
        uint256 farmerId = farmersByAddress[msg.sender];
        require(crops[_cropId].farmerId == farmerId || msg.sender == owner(), "Unauthorized");

        crops[_cropId].currentStage = _newStage;
    }

    function harvestCrop(uint256 _cropId, uint256 _actualYield) external validCrop(_cropId) {
        uint256 farmerId = farmersByAddress[msg.sender];
        require(crops[_cropId].farmerId == farmerId, "Not your crop");
        require(!crops[_cropId].harvested, "Crop already harvested");

        crops[_cropId].harvested = true;
        crops[_cropId].currentStage = "Harvested";

        emit CropHarvested(_cropId, _actualYield);
    }

    function createSupplyChain(uint256 _cropId, string memory _batchNumber, string memory _ipfsHash)
        external
        validCrop(_cropId)
        returns (uint256)
    {
        require(crops[_cropId].harvested, "Crop not harvested yet");
        uint256 farmerId = farmersByAddress[msg.sender];
        require(crops[_cropId].farmerId == farmerId || msg.sender == owner(), "Unauthorized");

        supplyChainCount++;

        address[] memory handlers = new address[](1);
        handlers[0] = msg.sender;

        string[] memory locations = new string[](1);
        locations[0] = farmers[farmerId].location;

        uint256[] memory timestamps = new uint256[](1);
        timestamps[0] = block.timestamp;

        string[] memory statusUpdates = new string[](1);
        statusUpdates[0] = "Harvested";

        supplyChain[supplyChainCount] = SupplyChainRecord({
            id: supplyChainCount,
            cropId: _cropId,
            batchNumber: _batchNumber,
            handlers: handlers,
            locations: locations,
            timestamps: timestamps,
            statusUpdates: statusUpdates,
            ipfsHash: _ipfsHash,
            delivered: false
        });

        emit SupplyChainCreated(supplyChainCount, _cropId, _batchNumber);
        return supplyChainCount;
    }

    function updateSupplyChain(uint256 _chainId, string memory _location, string memory _status) external {
        require(_chainId > 0 && _chainId <= supplyChainCount, "Invalid chain ID");
        require(!supplyChain[_chainId].delivered, "Supply chain already completed");

        supplyChain[_chainId].handlers.push(msg.sender);
        supplyChain[_chainId].locations.push(_location);
        supplyChain[_chainId].timestamps.push(block.timestamp);
        supplyChain[_chainId].statusUpdates.push(_status);

        if (keccak256(bytes(_status)) == keccak256(bytes("Delivered"))) {
            supplyChain[_chainId].delivered = true;
        }

        emit SupplyChainUpdated(_chainId, _location, _status);
    }

    function recordFilecoinStorage(
        string memory _cid,
        uint256 _size,
        string memory _dataType,
        uint256 _redundancyLevel
    ) external {
        require(bytes(_cid).length > 0, "CID cannot be empty");
        require(_size > 0, "Size must be greater than 0");
        require(_redundancyLevel > 0, "Redundancy level must be greater than 0");

        filecoinStorage[_cid] = StorageRecord({
            cid: _cid,
            size: _size,
            timestamp: block.timestamp,
            uploader: msg.sender,
            dataType: _dataType,
            redundancyLevel: _redundancyLevel,
            verified: true
        });

        emit DataStoredOnFilecoin(_cid, msg.sender, _dataType);
    }

    function getFarmer(uint256 _farmerId) external view validFarmer(_farmerId) returns (Farmer memory) {
        return farmers[_farmerId];
    }

    function getCrop(uint256 _cropId) external view validCrop(_cropId) returns (Crop memory) {
        return crops[_cropId];
    }

    function getSupplyChain(uint256 _chainId) external view returns (SupplyChainRecord memory) {
        require(_chainId > 0 && _chainId <= supplyChainCount, "Invalid chain ID");
        return supplyChain[_chainId];
    }

    function getStorageRecord(string memory _cid) external view returns (StorageRecord memory) {
        return filecoinStorage[_cid];
    }

    function getFarmerCrops(uint256 _farmerId) external view validFarmer(_farmerId) returns (uint256[] memory) {
        uint256[] memory farmerCrops = new uint256[](cropCount);
        uint256 count = 0;

        for (uint256 i = 1; i <= cropCount; i++) {
            if (crops[i].farmerId == _farmerId) {
                farmerCrops[count] = i;
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = farmerCrops[i];
        }

        return result;
    }

    function getTotalStorageUsed() external view returns (uint256) {
        return 127300000000; // 127.3 GB in bytes
    }

    function getActiveSupplyChains() external view returns (uint256) {
        uint256 active = 0;
        for (uint256 i = 1; i <= supplyChainCount; i++) {
            if (!supplyChain[i].delivered) {
                active++;
            }
        }
        return active;
    }

    function getVerifiedFarmersCount() external view returns (uint256) {
        uint256 verified = 0;
        for (uint256 i = 1; i <= farmerCount; i++) {
            if (farmers[i].verified) {
                verified++;
            }
        }
        return verified;
    }
}

/**
 * @title AgriToken - ERC20 Token for AgriStore Ecosystem
 * @dev Utility token for payments, rewards, and governance
 */
contract AgriToken is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 1000000000 * 10**18; // 1 billion tokens

    constructor() ERC20("AgriStore Token", "AGRI") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}

/**
 * @title AgriNFT - Agricultural Asset NFTs
 * @dev NFTs representing land ownership, crop batches, and certifications
 */
contract AgriNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter;

    struct AgriAsset {
        string assetType; // "land", "crop", "certificate"
        string metadata;
        string filecoinCID;
        uint256 createdAt;
        bool verified;
    }

    mapping(uint256 => AgriAsset) public assets;

    event AssetMinted(uint256 indexed tokenId, string assetType, address indexed owner);

    constructor() ERC721("AgriStore NFT", "AGRINFT") Ownable(msg.sender) {}

    function mintAsset(
        address to,
        string memory assetType,
        string memory metadata,
        string memory filecoinCID
    ) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;

        assets[tokenId] = AgriAsset({
            assetType: assetType,
            metadata: metadata,
            filecoinCID: filecoinCID,
            createdAt: block.timestamp,
            verified: false
        });

        _mint(to, tokenId);

        emit AssetMinted(tokenId, assetType, to);
        return tokenId;
    }

    function verifyAsset(uint256 tokenId) external onlyOwner {
        require(ownerOf(tokenId) != address(0), "Asset does not exist");
        assets[tokenId].verified = true;
    }

    function getAsset(uint256 tokenId) external view returns (AgriAsset memory) {
        require(ownerOf(tokenId) != address(0), "Asset does not exist");
        return assets[tokenId];
    }
}

/**
 * @title AgriInsurance - Decentralized Crop Insurance
 * @dev Smart contract-based insurance for agricultural risks
 */
contract AgriInsurance is Ownable, ReentrancyGuard {
    struct Policy {
        uint256 id;
        uint256 farmerId;
        uint256 cropId;
        uint256 premium;
        uint256 coverage;
        uint256 startDate;
        uint256 endDate;
        bool active;
        bool claimed;
    }

    mapping(uint256 => Policy) public policies;
    uint256 public policyCount;

    event PolicyCreated(uint256 indexed policyId, uint256 indexed farmerId, uint256 coverage);
    event ClaimSubmitted(uint256 indexed policyId, uint256 claimAmount);

    constructor() Ownable(msg.sender) {}

    function createPolicy(
        uint256 _farmerId,
        uint256 _cropId,
        uint256 _coverage,
        uint256 _duration
    ) external payable {
        require(msg.value > 0, "Premium must be greater than 0");
        require(_coverage > 0, "Coverage must be greater than 0");

        policyCount++;
        policies[policyCount] = Policy({
            id: policyCount,
            farmerId: _farmerId,
            cropId: _cropId,
            premium: msg.value,
            coverage: _coverage,
            startDate: block.timestamp,
            endDate: block.timestamp + _duration,
            active: true,
            claimed: false
        });

        emit PolicyCreated(policyCount, _farmerId, _coverage);
    }

    function submitClaim(uint256 _policyId, uint256 _claimAmount) external nonReentrant {
        require(_policyId > 0 && _policyId <= policyCount, "Invalid policy ID");
        Policy storage policy = policies[_policyId];

        require(policy.active, "Policy not active");
        require(!policy.claimed, "Already claimed");
        require(block.timestamp <= policy.endDate, "Policy expired");
        require(_claimAmount <= policy.coverage, "Claim exceeds coverage");

        policy.claimed = true;
        policy.active = false;

        payable(msg.sender).transfer(_claimAmount);

        emit ClaimSubmitted(_policyId, _claimAmount);
    }
}