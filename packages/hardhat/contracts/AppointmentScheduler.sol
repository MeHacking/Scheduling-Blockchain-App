// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProviderRegistry {
    function isApproved(address _addr) external view returns (bool);
}

contract AppointmentScheduler {

    struct Schedule {
        uint startTime;       // seconds in day (9 * 3600 => 09:00) 
        uint endTime;         // seconds in day (17 * 3600 => 17:00)
        uint slotDuration;    // 1200 sec => 20 min
        uint deposit;
        uint balance;
        bool initialized;
    }

    struct ClientAppointment {
        address provider;
        uint timestamp;
    }


    IProviderRegistry public providerRegistry;

    mapping(address => Schedule) public providerSchedules;
    mapping(address => mapping(uint => address)) public appointments; // provider => timestamp => client
    mapping(address => ClientAppointment[]) public clientAppointments; // client => (provider, timestamp)
    mapping(address => uint[]) public providerAppointments;

    event ScheduleSet(address indexed provider, uint startTime, uint endTime, uint slotDuration, uint deposit);
    event ScheduleUpdated(address indexed provider, uint startTime, uint endTime, uint slotDuration, uint deposit);
    event AppointmentBooked(address indexed provider, uint timestamp, address indexed client);
    event AppointmentCancelled(address indexed provider, uint timestamp, address indexed client);
    event AppointmentCompleted(address indexed provider, uint timestamp, address indexed client);

    modifier onlyProvider() {
        require(providerRegistry.isApproved(msg.sender), "Not an approved provider");
        _;
    }

    constructor(address _providerRegistry) {
        providerRegistry = IProviderRegistry(_providerRegistry);
    }

    function setSchedule(uint startTime, uint endTime, uint slotDuration, uint deposit) external onlyProvider {
        require(startTime < endTime, "Invalid working hours");
        require(slotDuration > 0, "Slot duration must be > 0");
        providerSchedules[msg.sender] = Schedule(startTime, endTime, slotDuration, deposit, 0, true);
        emit ScheduleSet(msg.sender, startTime, endTime, slotDuration, deposit);
    }

    function updateSchedule(uint startTime, uint endTime, uint slotDuration, uint deposit) external onlyProvider {
        uint balance = providerSchedules[msg.sender].balance;

        require(providerSchedules[msg.sender].initialized == true, "Schedule not set");
        require(startTime < endTime, "Invalid working hours");
        require(slotDuration > 0, "Slot duration must be > 0");

        providerSchedules[msg.sender] = Schedule(startTime, endTime, slotDuration, deposit, balance, true);
        emit ScheduleUpdated(msg.sender, startTime, endTime, slotDuration, deposit);
    }

    function bookAppointment(address provider, uint timestamp) external payable {
        require(timestamp > block.timestamp, "Appointment must be in the future");
        require(providerRegistry.isApproved(provider), "Provider not approved");

        Schedule memory s = providerSchedules[provider];
        require(s.slotDuration > 0, "Schedule not set");

        uint daySeconds = timestamp % 1 days;
        require(daySeconds >= s.startTime && daySeconds + s.slotDuration <= s.endTime, "Outside of working hours");
        require((daySeconds - s.startTime) % s.slotDuration == 0, "Invalid time slot");

        require(appointments[provider][timestamp] == address(0), "Slot already booked");
        require(msg.value == s.deposit, "Incorrect deposit");

        providerSchedules[provider].balance += msg.value;

        appointments[provider][timestamp] = msg.sender;
        clientAppointments[msg.sender].push(ClientAppointment(provider, timestamp));
        providerAppointments[provider].push(timestamp);

        emit AppointmentBooked(provider, timestamp, msg.sender);
    }

    function cancelAppointment(address provider, uint timestamp) external {
        require(appointments[provider][timestamp] == msg.sender, "Not your appointment");
        
        // Removing from appointments
        delete appointments[provider][timestamp];

        // Removing from clientAppointments
        ClientAppointment[] storage clientAppts = clientAppointments[msg.sender];
        for (uint i = 0; i < clientAppts.length; i++) {
            if (clientAppts[i].provider == provider && clientAppts[i].timestamp == timestamp) {
                clientAppts[i] = clientAppts[clientAppts.length - 1];
                clientAppts.pop();
                break;
            }
        }

        // Removing from providerAppointments
        uint[] storage providerAppts = providerAppointments[provider];
        for (uint i = 0; i < providerAppts.length; i++) {
            if (providerAppts[i] == timestamp) {
                providerAppts[i] = providerAppts[providerAppts.length - 1];
                providerAppts.pop();
                break;
            }
        }

        emit AppointmentCancelled(provider, timestamp, msg.sender);
    }

    function completeAppointment(uint timestamp) external onlyProvider {
        address customer = appointments[msg.sender][timestamp];
        require(customer != address(0), "Appointment does not exist");

        // Removing from appointments
        delete appointments[msg.sender][timestamp];

        // Removing from clientAppointments
        ClientAppointment[] storage clientAppts = clientAppointments[customer];
        for (uint i = 0; i < clientAppts.length; i++) {
            if (clientAppts[i].provider == msg.sender && clientAppts[i].timestamp == timestamp) {
                clientAppts[i] = clientAppts[clientAppts.length - 1];
                clientAppts.pop();
                break;
            }
        }

        // Removing from providerAppointments
        uint[] storage providerAppts = providerAppointments[msg.sender];
        for (uint i = 0; i < providerAppts.length; i++) {
            if (providerAppts[i] == timestamp) {
                providerAppts[i] = providerAppts[providerAppts.length - 1];
                providerAppts.pop();
                break;
            }
        }

        emit AppointmentCompleted(msg.sender, timestamp, customer);
    }

    function getAppointmentClient(address provider, uint timestamp) external view returns (address) {
        return appointments[provider][timestamp];
    }

    function getProviderSchedule(address provider) external view returns (Schedule memory) {
        return providerSchedules[provider];
    }

    function getProviderAppointments(address provider) external view returns (uint[] memory) {
        return providerAppointments[provider];
    }

    function getClientAppointments(address client) external view returns (ClientAppointment[] memory) {
        return clientAppointments[client];
    }

    function providerWithdraw() external onlyProvider {
        uint balance = providerSchedules[msg.sender].balance;
        require(balance > 0, "Not enough balance");

        providerSchedules[msg.sender].balance = 0;

        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");
    }
}