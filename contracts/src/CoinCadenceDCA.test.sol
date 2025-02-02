pragma solidity >=0.7.5;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../src/CoinCadenceDCA.sol";

contract CoinCadenceDCATest is Test {
    CoinCadenceDCA public dca;
    address public constant SWAP_ROUTER = address(1);
    address public constant FACTORY = address(2);

    function setUp() public {
        dca = new CoinCadenceDCA(SWAP_ROUTER, FACTORY);
    }

    function testCreateJobWithCurrentTimestamp() public {
        bytes memory path = abi.encodePacked(address(1), uint24(3000), address(2));
        address recipient = address(3);
        uint256 secondsToWaitForTx = 300;
        uint256 amountIn = 1e18;
        uint256 frequencyInSeconds = 86400;
        uint32 arithmeticMeanTickSecondsAgo = 1800;
        uint32 bpsSlippage = 100;

        bytes32 jobKey = dca.createJob(
            path,
            recipient,
            secondsToWaitForTx,
            amountIn,
            frequencyInSeconds,
            arithmeticMeanTickSecondsAgo,
            bpsSlippage,
            block.timestamp
        );

        CoinCadenceDCA.DCAJobProperties memory job = dca.getJob(jobKey);

        assertEq(job.prevRunTimestamp, block.timestamp, "Job prevRunTimestamp should be set to current block timestamp");
        assertEq(job.owner, address(this), "Job owner should be the test contract");
        assertTrue(job.initialized, "Job should be initialized");
    }

    function testCreateJobRevertsWithZeroAddressRecipient() public {
        bytes memory path = abi.encodePacked(address(1), uint24(3000), address(2));
        address zeroAddress = address(0);
        uint256 secondsToWaitForTx = 300;
        uint256 amountIn = 1e18;
        uint256 frequencyInSeconds = 86400;
        uint32 arithmeticMeanTickSecondsAgo = 300;
        uint32 bpsSlippage = 100;
        uint256 prevRunTimestamp = block.timestamp;

        vm.expectRevert("Recipient cannot be zero address");
        dca.createJob(
            path,
            zeroAddress,
            secondsToWaitForTx,
            amountIn,
            frequencyInSeconds,
            arithmeticMeanTickSecondsAgo,
            bpsSlippage,
            prevRunTimestamp
        );
    }

        function testCreateJobRevertsWithZeroAddressRecipient() public {

}
