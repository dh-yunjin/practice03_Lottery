// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Lottery.sol";

contract LotteryTest is Test {
    Lottery public lottery;
    uint256 received_msg_value;
    function setUp() public {
       lottery = new Lottery();
       received_msg_value = 0;
       // vm 객체는 foundry에서...https://jamesbachini.com/foundry-tutorial/
       vm.deal(address(this), 100 ether);
       vm.deal(address(1), 100 ether);
       vm.deal(address(2), 100 ether);
       vm.deal(address(3), 100 ether);
    }

    function testGoodBuy() public {
        lottery.buy{value: 0.1 ether}(0);
    }

    function testInsufficientFunds1() public {
        vm.expectRevert();
        lottery.buy(0);
    }

    function testInsufficientFunds2() public {
        vm.expectRevert();
        lottery.buy{value: 0.1 ether - 1}(0);
    }

    function testInsufficientFunds3() public {
        vm.expectRevert();
        lottery.buy{value: 0.1 ether + 1}(0);
        // 이건 왜 실패가 떠야만 하는지
        // 최대 베팅 금액을 0.1 ether로 고정하기 위함인가?
        // -vvv로 값을 보면 0.1 ether는 100000000000000000이고, 1을 빼면 9999..999
    }

    function testNoDuplicate() public {
        lottery.buy{value: 0.1 ether}(0);

        vm.expectRevert();
        lottery.buy{value: 0.1 ether}(0);
    } // 한 번에 1개의 lotto만 구매할 수 있도록...

    function testSellPhaseFullLength() public { // 함수명이 뭘 의미하는 것인지
        lottery.buy{value: 0.1 ether}(0);

        vm.warp(block.timestamp + 24 hours - 1); // 블록의 타임스탬프 설정
        // 왜 이런 값으로 설정하는 것인지? 왜 1을 빼는지?
        // 유추: 24시간이 지나면 전환 후 구매 불가
        // (즉 24시가 최대이기때문에 Phase FullLength)
        // block.timestamp = 생성되자마자 1로 세팅됨, 24 hours를 더하면 86401
        // 여기서 1을 빼니까 86400이 됨

        // 왜 구매가 불가능한 것인지...this가 발행자의 입장도 아닌데

        vm.prank(address(1)); // setting the next call's msg.sender as address
        // 정확히 어떤 것을 의미하는것인지 - this에서 1로 전환?

        lottery.buy{value: 0.1 ether}(0); // 전환 후 구매 - 정상
    }

    function testNoBuyAfterPhaseEnd() public {
        lottery.buy{value: 0.1 ether}(0);
        
        vm.warp(block.timestamp + 24 hours); 
        // 바로 위인 testSellPhaseFullLength와 비교했을 때, 
        // 달라진 점은 24 hours에 1을 빼지 않는 것 뿐...(86401)
        // 유추: 딱 24시간이 지나면 전환 후 구매가 불가

        vm.expectRevert();
        vm.prank(address(1)); 

        lottery.buy{value: 0.1 ether}(0);
    }
    // ---사실 상 여기까지 buy의 조건에 해당함
    // 0.1 ether + 1이 동작하지 않도록 할 것, 복제되지 않도록 할 것, 거래 끝난 다음 다른 buy 하지 않도록 할 것...

    // ---아래부터 draw, claim의 조건
    function testDraw() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();
    }

    function testNoDrawDuringSellPhase() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1); 

        vm.expectRevert();
        lottery.draw();
    } // testDraw와 비교했을 때 warp만 달라졌음 - 위와 동일하게 require 시간 조건
    // 다른 점은 반대로 24시간 전에는 draw를 못한다는 점..
    // -----------------------------

    function testNoClaimDuringSellPhase() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1);

        vm.expectRevert();
        lottery.claim();
    }
    // 위와 동일하게 require 시간 조건

    function getNextWinningNumber() private returns (uint16) {
        uint256 snapshotId = vm.snapshot();

        lottery.buy{value: 0.1 ether}(0);

        vm.warp(block.timestamp + 24 hours);

        lottery.draw();

        uint16 winningNumber = lottery.winningNumber();

        vm.revertTo(snapshotId);

        return winningNumber;
    } // 단순하게 winningNumber return만 해주면 됨
    // nextWinningNumber를 조작하는 로직이 draw에서 있을 것 같은데...

    function testClaimOnWin() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); vm.warp(block.timestamp + 24 hours);
        uint256 expectedPayout = address(lottery).balance; // lottery의 balance 개념
        lottery.draw();
        lottery.claim();
        assertEq(received_msg_value, expectedPayout);
    }

    function testNoClaimOnLose() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber + 1); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        assertEq(received_msg_value, 0);
    }
    // Win이랑 Lose의 차이점이 buy에서 전달되는 winningNumber인걸 보니...buy 시 bettingNumber를 전달해주는 개념같음

    function testNoDrawDuringClaimPhase() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();

        vm.expectRevert();
        lottery.draw();
    }
    // -------------------------------------
    function testRollover() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber + 1); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        // 져서 0.1 ether가 lottery에 저장되는게 맞음

        winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        // 이겨서 앞에서 저장된 0.1 ether랑 이번에 베팅한 0.1 ether를 가져옴

        assertEq(received_msg_value, 0.2 ether);
    } // 여기서 nextWinningNumber 로직이 밝혀질 줄 알았는데 그냥 winningNumber는 0 고정인...

    function testSplit() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber);

        // 주소 전환
        vm.prank(address(1));
        lottery.buy{value: 0.1 ether}(winningNumber);

        // 잔고 설정 - 초깃값 100eth - 0.1ether에서 0으로...
        vm.deal(address(1), 0);

        vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();

        assertEq(received_msg_value, 0.1 ether);

        // 주소 전환 (위에서 했는데 동일한 주소로 왜 또?)
        // Sets the next calls니까... 모르겠다
        vm.prank(address(1));
        lottery.claim();

        assertEq(address(1).balance, 0.1 ether);
    }

    receive() external payable {
        received_msg_value = msg.value;
    }
}