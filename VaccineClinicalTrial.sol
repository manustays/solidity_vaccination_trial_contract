// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.5;


/**
 * @title Utility super-class to provide basic ownership features
 */
contract Ownable {
    
    /// Current contract owner
    address public owner;
    
    /**
     * @dev Constructor to set contract creator as the initial owner.
     */
    constructor() {
        owner = msg.sender;
    }
    
    /// Allowed only by the owner
    modifier onlyOwner {
        require(msg.sender == owner, "Only the Token owner is allowed to do this!");
        _;
    }
}



/**
 * @title Base contract to keep track of authorized volunteers 
 */
contract Volunteers {
    
    struct Volunteer {
        uint256 dob;
        bytes1 gender; 
        bytes32 medical_precondition_hash;
        bool other_vaccine_taken;
        string other_vaccine_name;
        uint256 other_vaccination_date;
        
        bool doesExist;
        bool isApproved;
    }

    mapping (address => Volunteer) private volunteers;
    
    
    /**
     * Notify whenever a volunteer is added
     * @param volunteer Address of the added volunteer
     */
    event VolunteerAdded(address volunteer);
    
    /**
     * Notify whenever a volunteer is approved
     * @param volunteer Address of the volunteer approved
     */
    event VolunteerApproved(address volunteer);
    
    
    function addVolunteer(uint256 dob, bytes1 gender, bytes memory medical_precondition, bool other_vaccine_taken, string memory other_vaccine_name, uint256 other_vaccination_date) public {
        address volunteer = msg.sender;
        
        require(volunteers[volunteer].doesExist != true, "Volunteer already exists");
        
        volunteers[volunteer] = Volunteer({
            doesExist: true,
            isApproved: false,
            dob: dob,
            gender: gender,
            medical_precondition_hash: sha256(medical_precondition),
            other_vaccine_taken: other_vaccine_taken,
            other_vaccine_name: other_vaccine_name,
            other_vaccination_date: other_vaccination_date
        });
        
        emit VolunteerAdded(volunteer);
    }
    
    
    function removeVolunteer() public {
        volunteers[msg.sender].doesExist = false;
    }
    
    function isValidVolunteer(address volunteer) public view returns (bool) {
        return volunteers[volunteer].doesExist && volunteers[msg.sender].isApproved;
    }
    
    
    function _approveVolunteer(address volunteer) internal {
        volunteers[volunteer].isApproved = true;
        
        emit VolunteerApproved(volunteer);
    }
    
    
    function doesVolunteerExist(address volunteer) internal view returns (bool) {
        return volunteers[volunteer].doesExist;
    }

}




/**
 * @title The Vaccine CLinical Trials contract
 */
contract ClinicalTrial is Ownable, Volunteers {
    
    address private _owner;
    address private _clinicAuditor;
    
    bool _trialEnded;
    
    uint public NumberOfDose;
    string private _feedbackPerDose;
    
    modifier onlyAuditor {
        require(msg.sender == _clinicAuditor, "Only the Auditor is allowed to do perform action!");
        _;
    }
    
    enum _clinicState { NotVerified, Verified, NotFunctional }
    enum _volunteerState { NotVerified, Verified, InTrial, NotInTrial, CompletedTrial }
    
    struct Clinics {
        address id;
        string name;
        string location;
        string phoneNumber;
        _clinicState clinicState;
    }
    
    mapping(address => Clinics) clinics;
    mapping(address => uint) clinicRemovalRequest;
    
    event DoseGiven(address volunteer, uint doseNumber, uint remainingDaysForNextDose);
    event Clinic(address clinic, string eventName);
    event Global(string message);
    
    
    constructor (address clinicAuditor, uint numberOfDoses) {
        _owner = msg.sender;
        _clinicAuditor = clinicAuditor;
        NumberOfDose = numberOfDoses;
    }
    
    
    function enrollClinic (string memory clinicName, string memory clinicLocation, string memory clinicPhoneNumber) public returns (bool) {
        Clinics({
            id: msg.sender,
            name: clinicName,
            location: clinicLocation,
            phoneNumber: clinicPhoneNumber,
            clinicState: _clinicState.NotVerified
        });
        return true;
    }
    
    function authoriseClinic (address clinicAddress) public onlyAuditor returns (bool) {
        require(clinics[clinicAddress].clinicState != _clinicState.Verified, "Clinic already verfified.");
        clinics[clinicAddress].clinicState = _clinicState.Verified;
        emit Clinic(clinicAddress, "AuthoriseClinic");
        return true;
    }
    
    function deauthoriseClinic (address clinicAddress) public onlyAuditor returns (bool) {
        require(clinicRemovalRequest[clinicAddress] == 1, "No Removal Request Present.");
        clinics[clinicAddress].clinicState = _clinicState.NotFunctional;
        emit Clinic(clinicAddress, "De-AuthoriseClinic");
        return true;
    }
    
    function clinicRemovalReq () public returns (bool) {
        require(clinics[msg.sender].clinicState == _clinicState.Verified, "Clinic not verfified.");
        clinicRemovalRequest[msg.sender] = 1;
        emit Clinic(msg.sender, "RemoveClinicRequest");
        return true;
    }
    
    function EndTrial() public onlyOwner {
        require(!_trialEnded);
        _trialEnded = true;
        emit Global("Trials ended, thanks for your paticipation!");
    }

    
    
    /* ====================== By Abhishek ========================== */
    
    uint public total_valid_volunteers;
    uint public total_partially_vaccinated;
    uint public total_fully_vaccinated;
    uint public total_recovered;
    uint public total_invalid_results;

    
    struct Dose {
        uint dose_no;
        uint vaccinationDate;
        bool done;
    }
    
    struct DoseResult {
        bool published;
        bool success;
    }
    
    // Mapping of each dose given
    mapping(uint => mapping(address => Dose)) doses;
    
    // Mapping for the dose result
    mapping(uint => mapping(address => DoseResult)) doseResults;
    
    mapping(uint => mapping(address => string)) doseFeedbacks;
    
    
    modifier onlyValidClinic {
        require(clinics[msg.sender].clinicState == _clinicState.Verified, "Only an authorized clinic can do this!");
        _;
    }
    
    
    function approveVolunteer(address volunteer) public onlyValidClinic {
        
        require (doesVolunteerExist(volunteer), "Volunteer doesn't exist");
        
        _approveVolunteer(volunteer);
    }
    
    
    
    function markVaccinationDone(address volunteer, uint dose_no) public onlyValidClinic {
        
        require (isValidVolunteer(volunteer), "Not a valid volunteer");
        require(dose_no <= NumberOfDose, "Invalid dose number");
        
        if (dose_no > 1) {
            require(doses[dose_no-1][volunteer].done, "Last dose was not administered!");
        }
        
        doses[dose_no][volunteer] = Dose({
            dose_no: dose_no,
            vaccinationDate: block.timestamp,
            done: true
        });
        
        if (dose_no == NumberOfDose) {
            total_fully_vaccinated++;
        } else if (dose_no < NumberOfDose) {
            total_partially_vaccinated++;
        }
    }
    
    function markVaccinationResult(address volunteer, bool result) public onlyValidClinic {
        
        require (isValidVolunteer(volunteer), "Not a valid volunteer");
        require(doses[NumberOfDose][volunteer].done, "Result can only be set after finel dose is administered!");
        
        doseResults[NumberOfDose][volunteer] = DoseResult({
            published: true,
            success: result
        });
        
        if (result) {
            total_recovered++;
        }
    }


    function giveDoseFeedback(uint dose_no, string memory message) public {
        require (isValidVolunteer(msg.sender), "Not a valid volunteer");
        require (doseResults[dose_no][msg.sender].published, "Plz wait for dose result to be published!");
        
        doseFeedbacks[dose_no][msg.sender] = message;
        total_invalid_results++;
    }
    
    /* ============================================================= */
    
    
}
