// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ProviderRegistry {
    address public owner;
    uint256 public applicationFee;

    constructor(uint256 _applicationFee) {
        owner = msg.sender;
        applicationFee = _applicationFee;
    }

    enum ProviderStatus { None, Applied, Approved, Rejected }

    struct Provider {
        address wallet;
        string name;
        ProviderStatus status;
    }

    mapping(address => Provider) public providers;
    mapping(address => uint256) public rejectedTimestamps;
    address[] public providerList;
    address[] public pendingApplications;

    event Applied(address applicant);
    event Approved(address applicant);
    event Rejected(address applicant);
    event FeeUpdated(uint256 newFee);
    event ProviderRemoved(address provider);
    event NameChanged(address provider, string newName);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only admin can perform this action");
        _;
    }

    modifier notAlreadyApplied() {
        require(providers[msg.sender].status != ProviderStatus.Applied, "Already applied");
        _;
    }

    modifier notAlreadyApproved() {
        require(providers[msg.sender].status != ProviderStatus.Approved, "Already approved");
        _;
    }

    modifier notInTimeout() {
        uint256 lastRejection = rejectedTimestamps[msg.sender];
        require(lastRejection == 0 || block.timestamp >= lastRejection + 1 days, "Wait 24h before reapplying");
        _;
    }

    function removeFromPending(address applicant) internal {
        uint256 length = pendingApplications.length;
        for (uint256 i = 0; i < length; i++) {
            if (pendingApplications[i] == applicant) {
                pendingApplications[i] = pendingApplications[length - 1];
                pendingApplications.pop();
                break;
            }
        }
    }

    function removeProvider(address provider) external onlyOwner {
        uint256 length = providerList.length;
        providers[provider].status = ProviderStatus.None;
        for (uint256 i = 0; i < length; i++) {
            if (providerList[i] == provider) {
                providerList[i] = providerList[length - 1];
                providerList.pop();
                break;
            }
        }
        emit ProviderRemoved(provider);
    }

    function updateName(string memory newName) external {
        Provider storage provider = providers[msg.sender];
        require(provider.status == ProviderStatus.Approved, "You must be approved to update name");
        provider.name = newName;
        emit NameChanged(msg.sender, newName);
    }

    function applyAsProvider(string memory name) external payable notAlreadyApplied notAlreadyApproved notInTimeout {
        require(msg.value == applicationFee, "Incorrect payment amount");
        providers[msg.sender] = Provider(msg.sender, name, ProviderStatus.Applied);
        pendingApplications.push(msg.sender);
        emit Applied(msg.sender);
    }

    function approveProvider(address applicant) external onlyOwner {
        require(providers[applicant].status == ProviderStatus.Applied, "Not pending");
        providers[applicant].status = ProviderStatus.Approved;
        removeFromPending(applicant);
        providerList.push(applicant);
        emit Approved(applicant);
    }

    function rejectApplication(address applicant) external onlyOwner {
        require(providers[applicant].status == ProviderStatus.Applied, "Not pending");
        providers[applicant].status = ProviderStatus.Rejected;
        rejectedTimestamps[applicant] = block.timestamp;
        removeFromPending(applicant);
        emit Rejected(applicant);
    }

    function updateFee(uint256 newFee) external onlyOwner {
        applicationFee = newFee;
        emit FeeUpdated(newFee);
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function getAllProviders() external view returns (address[] memory) {
        return providerList;
    }

    function getPendingApplications() external view onlyOwner returns (address[] memory) {
        return pendingApplications;
    }

    function isApproved(address _addr) external view returns (bool) {
        return providers[_addr].status == ProviderStatus.Approved;
    }

    function isRejected(address _addr) external view returns (bool) {
        return providers[_addr].status == ProviderStatus.Rejected;
    }

    function checkStatus(address _addr) external view returns (ProviderStatus)  {
        return providers[_addr].status;
    }

    function refreshStatus() public {
        if (providers[msg.sender].status == ProviderStatus.Rejected && block.timestamp >= rejectedTimestamps[msg.sender] + 1 days) {
            providers[msg.sender].status = ProviderStatus.None;
            rejectedTimestamps[msg.sender] = 0;
        }
    }
}
