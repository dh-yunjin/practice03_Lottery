// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Lottery{
    mapping(address => uint256) public lottery_balances; // 예치금(구매한 lottery)
    uint16 _winningNumber;
    mapping(address => uint16) public _bettingNumber;
    uint256 balance; // testClaimOnWin 에서...lottery도 자체적인 balance를 갖고있어야 함
    // 그냥 직관적으로 이해해보면 lottery를 구매할 때 마다 balance를 늘려주면 되지 않을까 싶음
    // 로또 시스템 자체가 구매금 모두 모아서 1명에게 몰빵 개념이다 보니까
    constructor () {
        _winningNumber = 0;
    }

/* 해결 순서
    testInsufficientFunds1~3
    testGoodBuy
    testNoDuplicate
    testNoBuyAfterPhaseEnd (동시) testSellPhaseFullLength

    testNoDrawDuringSellPhase
    getNextWinningNumber

    testNoClaimOnLose (동시) testNoClaimOnWin // 제대로 해결 X
    testNoDrawDuringClaimPhase

    testRollover // Claim이 해결되어야 함

    testSplit // 
*/
    function buy(uint16 bettingNumber) public payable{ // 반환값이 따로 없으면 returns 안적어줘도 됨
        // uint16이 맞는지..._winningNumber가 어떤 역할인지...죄다 buy(0)인데 winningNumber만 변수임

        // {value: 값} 이런 식으로 넘겨주면 payable을 작성해줘야 하는 듯
        // 사용은 msg.value
        // https://dayone.tistory.com/33
        // payable을 통해서 이더를 받는 함수임을...

        // msg.sender와 user의 차이 - msg.sender는 contract에 해당하지 않을까...
        // 구분이 필요 - 근데 Lottery.sol에서도 address(1) 이런식으로 접근이 가능한가?
        // (착각) parameter가 user인줄 알았는데 bettingNumber였음

        require(lottery_balances[msg.sender] == 0);
        // testNoDuplicate 이미 구입한 상태에서 다시 구입 불가

        require(block.timestamp <= 24 hours);
        // testNoBuyAfterPhaseEnd 
        // testSellPhaseFullLength
        // 이렇게 간단하다고?
        // block은 컨트랙트에 귀속되는건가?        

        require(msg.value != 0);
        // testInsufficientFunds1 // 복권을 0 eth 이상은 구매해야

        require(msg.sender.balance >= msg.value); // 복권을 구매할 잔고가 충분한지
        // testInsufficientFunds2

        require(msg.value == 0.1 ether); // 최대(고정) 베팅 금액?
        // testInsufficientFunds3
        
        // msg.sender.balance -= msg.value; // 잔고 차감은 컨트랙트 들어오면서 지불된듯?
        lottery_balances[msg.sender] += msg.value; // 구입 금액
        _bettingNumber[msg.sender] = bettingNumber;// claim
        balance += msg.value; //claim
    }

    function draw() public{ 
        // 그래서 대체 무슨 역할인지... - 단어 상으로는 "인출"
        // ★★★ 이 draw 단계에서 뭐가 부족해서 claim도 안되는 것이 아닐까 유추해봄
        require(block.timestamp > 24 hours);
        // testNoDrawDuringSellPhase

        require(lottery_balances[msg.sender] != 0);
        // testNoDrawDuringClaimPhase
        // claim 중에 draw를 수행하지 못하게 → claim 수행 시 반드시 lottery_balnaces 초기화 과정을 거치므로...
    } 

    function claim() public{ // quiz에서 했다시피..."지불"하는 것을 의미함(결과에 따라)
        require(block.timestamp > 24 hours);
        // testNoClaimDuringSellPhase (근데 이거 적기 전에도 pass였음)
        
        // msg.value = msg.sender.balance; 으로 대입 불가 (둘 다 left value임)
        if(_winningNumber == _bettingNumber[msg.sender]){
            // payable(msg.sender).transfer(balance); // 누가 어떤 자금으로 송금하는것인지?
            // ★★★개념은 맞는 것 같은데 뭔가 송금이 안되는데, 이유를 모르겠습니다★★★
            // testClaimOnWin testNoClaimOnLose
            lottery_balances[msg.sender] = 0;
            balance = 0;
            

        }
        // WIN, 지금까지 쌓인 금액 = lottery.balance를 가지게 됨
        else{
            lottery_balances[msg.sender] = 0;
        }

        // assertEq(received_msg_value, expectedPayout); 를 만족시켜야 함
        // received_msg_value는 receive()에 의해 msg.value와 동일함
        // expectedPayout은 address(lottery).balance; - 변수 선언 필요성


        /* 참고용: practice02_Quiz
        uint256 amount = lottery_balances[msg.sender];
        lottery_balances[msg.sender] = 0; // 베팅한 금액 초기화
        payable(msg.sender).transfer(amount); // 상금 주기
        // win, lose에 따라 amount가 변동됨 */
        
    }
    function winningNumber() public view returns(uint16){



        return _winningNumber;
        // getNextWinningNumber
    }
}
