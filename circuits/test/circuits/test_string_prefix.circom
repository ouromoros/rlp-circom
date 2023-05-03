pragma circom 2.0.1;

include "../../circuits/rlp.circom";

template TestRLPListPrefix() {
    var maxLen = 1000;
    // Input, RLP representation of the block.
    signal input data[1000]; // 1000 bytes of RLP encodingkk
    signal output prefixLen;
    signal output valueLen;

    component rlpHeader = RLPDecodeString(maxLen, 0, maxLen, 0);
    for (var i = 0; i < maxLen; i++) {
        rlpHeader.data[i] <== data[i];
    }
    prefixLen <== rlpHeader.prefixLen;
    valueLen <== rlpHeader.valueLen;
}

component main {public [data]} = TestRLPListPrefix();
