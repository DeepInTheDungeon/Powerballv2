// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.18;

contract Lottery is Ownable {
    mapping (address => uint256) public userEntries;
    address[] public users;  // An array to keep track of the users
    mapping (address => bool) private winners; // winners map
    uint256 public minimumBuyIn = .1 ether;
    uint256 public lotteryPool = 0 ether;
    uint256 public drawingPerCall = 7;

    event LotteryDeposit(address indexed wallet, uint256 amount, uint256 entries);
    event LotteryPayout(address indexed winner, uint256 amount);
    event LotteryEntriesReset(string message);

function deposit() external payable {
    require(msg.value >= minimumBuyIn, "Deposit does not meet the minimumBuyIn requirement.");

    uint256 entries = msg.value / minimumBuyIn;
    uint256 bonusEntries = entries / 4; // Give 1 bonus entry for every 4 entries bought

    // Add 5 bonus entries if user bought 10 or more entries
    if(entries >= 10) {
        bonusEntries += 5;
    }

    entries += bonusEntries; // Add bonus entries to total entries

    if (userEntries[msg.sender] == 0) {
        users.push(msg.sender);  // Push the user to users array if this is the first time they are participating
    }

    userEntries[msg.sender] += entries;

    lotteryPool += msg.value;
    emit LotteryDeposit(msg.sender, msg.value, entries); 
}

    function generateRandomHex() internal view returns (bytes4) {
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, blockhash(block.number - 1))));
        bytes32 randomBytes32 = bytes32(randomNumber);
        bytes4 hexString = bytes4(randomBytes32);
        return hexString;
    }

    function checkMatch(address _address, bytes2 _hexSequence) internal pure returns (bool) {
        bytes memory addressBytes = abi.encodePacked(_address);
        bytes memory hexSequenceBytes = abi.encodePacked(_hexSequence);

        for (uint256 i = 0; i < addressBytes.length - hexSequenceBytes.length + 1; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < hexSequenceBytes.length; j++) {
                if (addressBytes[i + j] != hexSequenceBytes[j]) {
                    isMatch = false;
                    break;
                }
            }
            if (isMatch) {
                return true;
            }
        }
        return false;
    }

    function resetUserEntries() internal {
        for (uint256 i = 0; i < users.length; i++){
            delete userEntries[users[i]];
            delete winners[users[i]]; // Also reset winners
        }
        delete users;  // Reset the users array
    }

    function draw() external onlyOwner {
        bytes4[] memory drawings = new bytes4[](drawingPerCall);
        address[] memory winnersArr = new address[](users.length);  // Store winners in an array
        uint256 winnersCount = 0;

        for (uint256 ii = 0; ii < drawings.length; ii++) { 
            bytes2 drawingFirstTwoBytes = bytes2(drawings[ii]);
            for (uint256 i = 0; i < users.length; i++) {
                address user = users[i];
                bool isMatch = checkMatch(user, drawingFirstTwoBytes);
                if (isMatch && winners[user] == false) {
                    winners[user] = true;
                    winnersArr[winnersCount] = user;  // Add the winner to winnersArr
                    winnersCount++;
                }
            }
        }

        uint256 lotteryEarningsPerWinningAddress = 0;
        if (winnersCount > 0) {
            lotteryEarningsPerWinningAddress = lotteryPool / winnersCount;
            for (uint256 i = 0; i < winnersCount; i++) { 
                address winner = winnersArr[i];
                payable(winner).transfer(lotteryEarningsPerWinningAddress);
                emit LotteryPayout(winner, lotteryEarningsPerWinningAddress);
            }
            resetUserEntries();
            emit LotteryEntriesReset("entries flushed");
        }
    }

}
