pragma circom 2.0.1;

include "../../../node_modules/circomlib/circuits/comparators.circom";
include "../../circuits/rlp.circom";
include "../../../node_modules/circom-pairing/circuits/bigint_func.circom";

template ShiftRight(nIn, nInBits) {
    signal input in[nIn];
    signal input shift;
    signal output out[nIn];

    component n2b = Num2Bits(nInBits);
    n2b.in <== shift;

    signal shifts[nInBits][nIn];
    for (var idx = 0; idx < nInBits; idx++) {
        if (idx == 0) {
	        for (var j = 0; j < min((1 << idx), nIn); j++) {
                shifts[0][j] <== - n2b.out[idx] * in[j] + in[j];
            }
	        for (var j = (1 << idx); j < nIn; j++) {
	            var tempIdx = j - (1 << idx);
                shifts[0][j] <== n2b.out[idx] * (in[tempIdx] - in[j]) + in[j];
            }
        } else {
            for (var j = 0; j < min((1 << idx), nIn); j++) {
                var prevIdx = idx - 1;
                shifts[idx][j] <== - n2b.out[idx] * shifts[prevIdx][j] + shifts[prevIdx][j];
            }
            for (var j = (1 << idx); j < nIn; j++) {
                var prevIdx = idx - 1;
                var tempIdx = j - (1 << idx);
                shifts[idx][j] <== n2b.out[idx] * (shifts[prevIdx][tempIdx] - shifts[prevIdx][j]) + shifts[prevIdx][j];
            }
        }
    }
    for (var i = 0; i < nIn; i++) {
        out[i] <== shifts[nInBits - 1][i];
    }
}

template bytesToBigInt(n) {
    signal input in[n];
    signal input inHexLen;
    signal output out;

    assert(n <= 64);
    // assume 6 >= log2(n)
    component shiftRight = ShiftRight(n, 6);
    shiftRight.in <== in;
    shiftRight.shift <== n - inHexLen;

    // for (var idx = 0; idx < n; idx++) {
    //     log(shiftRight.out[idx]);
    // }

    var temp = 0;
    for (var idx = 0; idx < n; idx++) {
        temp = 256 * temp + shiftRight.out[idx];
    }
    out <== temp;
}

template TestRLPHeader() {
    var maxLen = 1075;
    // Input, RLP representation of the block.
    signal input data[maxLen]; // 2150 bytes of RLP encoding
    // Outputs.
    signal output coinbase;
    signal output chainId;
    signal output blockNumber;

    // RLP stuff
    component rlp = RLPDecodeFixedList(
        maxLen,
        16,
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [1,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0],
        [0,  32, 32, 20, 32, 32, 32, 256,  0,  0,  0,  0,  0,  32, 32, 8],
        [32, 32, 32, 20, 32, 32, 32, 256, 32, 32,  8,  8,  8, 452, 32, 8],
        0);

    for (var idx = 0; idx < maxLen; idx++) {
    	rlp.data[idx] <== data[idx];
    }

    // account address
    var temp = 0;
    for (var idx = 0; idx < 20; idx++) {
        temp = 256 * temp + rlp.fields[3][idx];
    }
    coinbase <== temp;
    log("account address is:");
    log(coinbase);

    // chain ID
    component b2b = bytesToBigInt(32);
    for (var idx = 0; idx < 32; idx++) {
        b2b.in[idx] <== rlp.fields[0][idx];
    }
    b2b.inHexLen <== rlp.fieldLens[0];
    chainId <== b2b.out;
    log("chain ID is:");
    log(chainId);

    // block number
    component b2bNumber = bytesToBigInt(32);
    for (var idx = 0; idx < 32; idx++) {
        b2bNumber.in[idx] <== rlp.fields[9][idx];
    }
    b2bNumber.inHexLen <== rlp.fieldLens[9];
    blockNumber <== b2bNumber.out;
    log("block number is:");
    log(blockNumber);
}

component main {public [data]} = TestRLPHeader();
