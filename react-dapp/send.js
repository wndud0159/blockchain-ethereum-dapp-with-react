module.exports = function (callback) {
    web3.eth.sendTransaction({ from:web3.eth.accounts[9], to: "0xAC5fDb1B2a7F74EED7883751AB17f589dB53E35E", value: web3.toWei(30, "ether") }, callback);
    // 가나슈에서 만들어준 가상의 계정 9번째의 이더30을 내가 생성한 계정에 송금 코드
}