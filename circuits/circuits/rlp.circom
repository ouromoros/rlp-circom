pragma circom 2.0.2;
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/switcher.circom";

function num_bits2(n) {
    var n_temp = n;
    for (var i = 0; i < 256; i++) {
       if (n_temp == 0) {
          return i;
       }
       n_temp = n_temp \ 2;
   }
   return 255;
}

template ShiftLeft(nIn, minShift, maxShift) {
    signal input data[nIn];
    signal input shift;
    signal output out[nIn];

    var shiftBits = num_bits2(maxShift - minShift);

    component n2b;
    signal shifts[shiftBits][nIn];
    
    if (minShift == maxShift) {
        assert(shift == minShift);
        for (var i = 0; i < nIn; i++) {
	        out[i] <== data[(i + minShift) % nIn];
	    }
    } else {
        n2b = Num2Bits(shiftBits);
	    n2b.in <== shift - minShift;

        for (var idx = 0; idx < shiftBits; idx++) {
            if (idx == 0) {
                for (var j = 0; j < nIn; j++) {
                    var tempIdx = (j + minShift + (1 << idx)) % nIn;
                    var tempIdx2 = (j + minShift) % nIn;
                    shifts[0][j] <== n2b.out[idx] * (data[tempIdx] - data[tempIdx2]) + data[tempIdx2];
                }
            } else {
                for (var j = 0; j < nIn; j++) {
                    var prevIdx = idx - 1;
                    var tempIdx = (j + (1 << idx)) % nIn;
                    shifts[idx][j] <== n2b.out[idx] * (shifts[prevIdx][tempIdx] - shifts[prevIdx][j]) + shifts[prevIdx][j];
                }
            }
        }
        for (var i = 0; i < nIn; i++) {
            out[i] <== shifts[shiftBits - 1][i];
        }
    }
}

/*
 * Check the validity of fixed-schema encoded list. Note that we only do a *shallow* check. The caller 
 * needs to do RLPCheckFixedList() for the inner list items if present.
 * `maxLen`: the maximum length of the input data.
 * `fieldNum`: the number of fields in the list.
 * `isListArray`: an array of length `fieldNum` indicating whether the field is a list.
 * `getField`: an array of length `fieldNum` indicating whether the field content should be extracted to output.
 * `fieldMinArray`: an array of length `fieldNum` indicating the minimum length of the field.
 * `fieldMaxArray`: an array of length `fieldNum` indicating the maximum length of the field.
 * `enforceInput`: whether to enforce the input data to be 8-bit bytes.
 */
template RLPDecodeFixedList(maxLen, fieldNum, isListArray, getFieldArray, fieldMinArray, fieldMaxArray, enforceInput) {
    var computedTotalMinLen = 0;
    var computedTotalMaxLen = 0;
    for (var i = 0; i < fieldNum; i++) {
        computedTotalMinLen += fieldMinArray[i] + isListArray[i];
        computedTotalMaxLen += fieldMaxArray[i] + maxBytesForLength(fieldMaxArray[i]);
    }
    assert(maxLen >= computedTotalMaxLen);

    // input bytes.
    signal input data[maxLen];
    // is a valid RLP encoded list
    signal output valid;
    // fields values
    signal output fields[fieldNum][maxLen];
    // field lengths
    signal output fieldLens[fieldNum];

    component byteCheck;
    if (enforceInput == 1) {
        // Do a num2bits enforce on each input
        for (var i = 0; i < maxLen; i++) {
            byteCheck = Num2Bits(8);
            byteCheck.in <== data[i];
        }
    }

    component decodeList = RLPDecodeList(maxLen, computedTotalMinLen, maxLen, 0);
    for (var i = 0; i < maxLen; i++) {
        decodeList.data[i] <== data[i];
    }
    log("list prefix is: ", decodeList.prefixLen);
    component shiftListPrefix = ShiftLeft(maxLen, 0, 4);
    for (var i = 0; i < maxLen; i++) {
        shiftListPrefix.data[i] <== data[i];
    }
    shiftListPrefix.shift <== decodeList.prefixLen;

    var currentData[maxLen];
    for (var i = 0; i < maxLen; i++) {
        currentData[i] = shiftListPrefix.out[i];
    }
    var currentPosition = decodeList.prefixLen;
    component decodeField[fieldNum];
    for (var i = 0; i < fieldNum; i++) {
        decodeField[i] = RLPDecodeSelect(maxLen, fieldMinArray[i], fieldMaxArray[i], isListArray[i], getFieldArray[i]);
        for (var j = 0; j < maxLen; j++) {
            decodeField[i].data[j] <== currentData[j];
        }
        log("current position is: ", currentPosition, ", first byte should be ", data[currentPosition]);
        log("currentData[0] is: ", currentData[0]);
        log("filed[", i, "] prefix length is: ", decodeField[i].prefixLen);
        log("filed[", i, "] value length is: ", decodeField[i].valueLen);
        currentPosition += decodeField[i].prefixLen + decodeField[i].valueLen;

        for (var j = 0; j < fieldMaxArray[i]; j++) {
            fields[i][j] <== decodeField[i].out[j];
        }
        for (var j = fieldMaxArray[i]; j < maxLen; j++) {
            fields[i][j] <== 0;
        }
        fieldLens[i] <== decodeField[i].valueLen;

        for (var j = 0; j < maxLen;j ++) {
            currentData[j] = decodeField[i].shiftedData[j];
        }
    }

    signal validProduct[fieldNum];
    validProduct[0] <== decodeList.valid * decodeField[0].valid;
    for (var i = 1; i < fieldNum; i++) {
        validProduct[i] <== validProduct[i-1] * decodeField[i].valid;
    }
    valid <== validProduct[fieldNum-1];
}

template RLPDecodeSelect(dataMaxLen, valueMinLen, valueMaxLen, isList, getField) {
    signal input data[dataMaxLen];

    signal output valid;
    signal output prefixLen;
    signal output valueLen;
    signal output out[valueMaxLen]; // list value
    signal output shiftedData[dataMaxLen]; // `data` shifted to the end of encoded string

    component decodeList;
    component decodeString;
    var validVar, prefixLenVar, valueLenVar;

    if (isList) {
        decodeList = RLPDecodeList(dataMaxLen, valueMinLen, valueMaxLen, getField);
        for (var i = 0; i < dataMaxLen; i++) {
            decodeList.data[i] <== data[i];
        }
        for (var i = 0; i < valueMaxLen; i++) {
            out[i] <== decodeList.out[i];
        }
        for (var i = 0; i< dataMaxLen; i++) {
            shiftedData[i] <== decodeList.shiftedData[i];
        }
        valid <== decodeList.valid;
        prefixLen <== decodeList.prefixLen;
        valueLen <== decodeList.valueLen;
    } else {
        decodeString = RLPDecodeString(dataMaxLen, valueMinLen, valueMaxLen, getField);
        for (var i = 0; i < dataMaxLen; i++) {
            decodeString.data[i] <== data[i];
        }
        for (var i = 0; i < valueMaxLen; i++) {
            out[i] <== decodeString.out[i];
        }
        for (var i = 0; i< dataMaxLen; i++) {
            shiftedData[i] <== decodeString.shiftedData[i];
        }
        valid <== decodeString.valid;
        prefixLen <== decodeString.prefixLen;
        valueLen <== decodeString.valueLen;
    }

}

function maxBytesForLength(len) {
    if (len < 55) {
        return 1;
    } else if (len < 256) {
        return 2;
    } else if (len < 65536) {
        return 3;
    } else if (len < 16777216) {
        return 4;
    } else {
        return -1;
    }
}

template RLPDecodeList(dataMaxLen, listMinLen, listMaxLen, getField) {
    assert(dataMaxLen < 16777216);
    var maxPrefixLength = maxBytesForLength(listMaxLen);
    var minPrefixLength = 1;
    signal input data[dataMaxLen];

    signal output valid;
    signal output prefixLen;
    signal output valueLen;
    signal output out[listMaxLen]; // list value
    signal output shiftedData[dataMaxLen]; // `data` shifted to the end of encoded string

    var validVar = 0;
    var prefixLenVar = 0;
    var valueLenVar = 0;

    signal byte0, byte1, byte2, byte3;
    signal valid0, valid1, valid2, valid3;
    signal valueLen0, valueLen1, valueLen2, valueLen3;
    signal finalValueLen0, finalValueLen1, finalValueLen2, finalValueLen3;
    component index0, index1, index2, index3;
    component checkFirstByte1, checkFirstByte2, checkFirstByte3;
    component inRange1, inRange2, inRange3;

    byte0 <== data[0];

    component lowerBound = LessThan(8);
    lowerBound.in[0] <== 191;
    lowerBound.in[1] <== byte0;
    component upperBound = LessThan(8);
    upperBound.in[0] <== byte0;
    upperBound.in[1] <== 248;
    valid0 <== lowerBound.out * upperBound.out;
    valueLen0 <== byte0 - 192;
    finalValueLen0 <== valid0 * valueLen0;

    // We can add the values because only one of them will be valid due to the property of
    // the RLP encoding. Any prefix with any value after it will only have one decoding theme.
    validVar += valid0;
    prefixLenVar += 1 * valid0;
    valueLenVar = valueLen0 * valid0;
    // One additional prefix byte
    if (listMaxLen > 55) {
        byte1 <== data[1];
        valueLen1 <== byte1;

        checkFirstByte1 = IsEqual();
        checkFirstByte1.in[0] <== 248;
        checkFirstByte1.in[1] <== byte0;
        inRange1 = LessThan(8);
        inRange1.in[0] <== 55;
        inRange1.in[1] <== valueLen1;
        valid1 <== checkFirstByte1.out * inRange1.out;

        validVar += valid1; 
        prefixLenVar += 2 * valid1;
        finalValueLen1 <== finalValueLen0 + valueLen1 * valid1;
        valueLenVar = finalValueLen1;
    }

    // Two additional prefix bytes
    if (listMaxLen >= 256) {
        byte2 <== data[2];
        valueLen2 <== byte2 + byte1 * (1 << 8);

        checkFirstByte2 = IsEqual();
        checkFirstByte2.in[0] <== 249;
        checkFirstByte2.in[1] <== byte0;
        inRange2 = LessThan(16);
        inRange2.in[0] <== 255;
        inRange2.in[1] <== valueLen2;
        valid2 <== checkFirstByte2.out * inRange2.out;

        validVar += valid2; 
        prefixLenVar += 3 * valid2;
        finalValueLen2 <== finalValueLen1 + valueLen2 * valid2;
        valueLenVar = finalValueLen2;
    }

    // Three additional prefix bytes
    if (listMaxLen >= 65536) {
        byte3 <== data[3];
        valueLen3 <== byte3 + byte2 * (1 << 8) + byte1 * (1 << 16);

        checkFirstByte3 = IsEqual();
        checkFirstByte3.in[0] <== 250;
        checkFirstByte3.in[1] <== byte0;
        inRange3 = LessThan(24);
        inRange3.in[0] <== 65535;
        inRange3.in[1] <== valueLen3;
        valid3 <== checkFirstByte3.out * inRange3.out;

        validVar += valid3; 
        prefixLenVar += 4 * valid3;
        finalValueLen3 <== finalValueLen2+ valueLen3 * valid3;
        valueLenVar = finalValueLen3;
    }
    // We could add more here, but that's probably enough for now

    component prefixShifted, valueShifted, allShifted;
    if (getField == 0) {
        for (var i = 0; i < listMaxLen; i++) {
            out[i] <== 0;
        }
        allShifted = ShiftLeft(dataMaxLen, listMinLen + minPrefixLength, listMaxLen + maxPrefixLength);
        for (var i = 0; i < dataMaxLen; i++) {
            allShifted.data[i] <== data[i];
        }
        allShifted.shift <== prefixLenVar + valueLenVar;
        for (var i = 0; i < dataMaxLen; i++) {
            shiftedData[i] <== allShifted.out[i];
        }
    } else {
        prefixShifted = ShiftLeft(dataMaxLen, minPrefixLength, maxPrefixLength);
        for (var i = 0; i < dataMaxLen; i++) {
            prefixShifted.data[i] <== data[i];
        }
        prefixShifted.shift <== prefixLenVar;
        for (var i = 0; i < listMaxLen; i++) {
            out[i] <== prefixShifted.out[i];
        }
        valueShifted = ShiftLeft(dataMaxLen, listMinLen, listMaxLen);
        for (var i = 0; i < dataMaxLen; i++) {
            valueShifted.data[i] <== prefixShifted.out[i];
        }
        valueShifted.shift <== valueLenVar;

        for (var i = 0; i < dataMaxLen; i++) {
            shiftedData[i] <== valueShifted.out[i];
        }
    }
    valid <== validVar;
    prefixLen <== prefixLenVar;
    valueLen <== valueLenVar;
}

/*
 * Checks the validity of an encoded string prefix.
 * `data` should contain the original data left-shifted to the start of encoded string.
 */
template RLPDecodeString(dataMaxLen, stringMinLen, stringMaxLen, getField) {
    assert(stringMaxLen < 16777216);
    var minPrefixLength = 0;
    var maxPrefixLength = maxBytesForLength(stringMaxLen);
    signal input data[dataMaxLen];

    signal output valid;
    signal output prefixLen;
    signal output valueLen;
    signal output out[stringMaxLen]; // string value
    signal output shiftedData[dataMaxLen]; // `data` shifted to the end of encoded string

    var validVar = 0;
    var prefixLenVar = 0;
    var valueLenVar = 0;

    signal byte0, byte1, byte2, byte3;
    signal validbyte, valid0, valid1, valid2, valid3;
    signal valueLenByte, valueLen0, valueLen1, valueLen2, valueLen3;
    signal finalValueByteLen, finalValueLen0, finalValueLen1, finalValueLen2, finalValueLen3;
    component index0, index1, index2, index3;
    component checkFirstByte1, checkFirstByte2, checkFirstByte3;
    component inRange1, inRange2, inRange3;

    byte0 <== data[0];

    component singleByteUpperBound = LessThan(8);
    singleByteUpperBound.in[0] <== byte0;
    singleByteUpperBound.in[1] <== 128;
    validbyte <== singleByteUpperBound.out;
    valueLenByte <== 1;
    prefixLenVar += 0; // no prefix
    finalValueByteLen <== validbyte * valueLenByte;

    component lowerBound = LessThan(8);
    lowerBound.in[0] <== 127;
    lowerBound.in[1] <== byte0;
    component upperBound = LessThan(8);
    upperBound.in[0] <== byte0;
    upperBound.in[1] <== 184;
    valid0 <== lowerBound.out * upperBound.out;
    valueLen0 <== byte0 - 128;
    finalValueLen0 <== finalValueByteLen + valid0 * valueLen0;

    // We can add the values because only one of them will be valid due to the property of
    // the RLP encoding. Any prefix with any value after it will only have one decoding theme.
    validVar += valid0;
    prefixLenVar += 1 * valid0;
    valueLenVar = finalValueLen0;
    // One additional prefix byte
    if (stringMaxLen > 55) {
        byte1 <== data[1];
        valueLen1 <== byte1;

        checkFirstByte1 = IsEqual();
        checkFirstByte1.in[0] <== 184;
        checkFirstByte1.in[1] <== byte0;
        inRange1 = LessThan(8);
        inRange1.in[0] <== 55;
        inRange1.in[1] <== valueLen1;
        valid1 <== checkFirstByte1.out * inRange1.out;

        validVar += valid1; 
        prefixLenVar += 2 * valid1;
        finalValueLen1 <== finalValueLen0 + valueLen1 * valid1;
        valueLenVar = finalValueLen1;
    }

    // Two additional prefix bytes
    if (stringMaxLen >= 256) {
        byte2 <== data[2];
        valueLen2 <== byte2 + byte1 * (1 << 8);

        checkFirstByte2 = IsEqual();
        checkFirstByte2.in[0] <== 185;
        checkFirstByte2.in[1] <== byte0;
        inRange2 = LessThan(16);
        inRange2.in[0] <== 255;
        inRange2.in[1] <== valueLen2;
        valid2 <== checkFirstByte2.out * inRange2.out;

        validVar += valid2; 
        prefixLenVar += 3 * valid2;
        finalValueLen2 <== finalValueLen1 + valueLen2 * valid2;
        valueLenVar = finalValueLen2;
    }

    // Three additional prefix bytes
    if (stringMaxLen >= 65536) {
        byte3 <== data[3];
        valueLen3 <== byte3 + byte2 * (1 << 8) + byte1 * (1 << 16);

        checkFirstByte3 = IsEqual();
        checkFirstByte3.in[0] <== 186;
        checkFirstByte3.in[1] <== byte0;
        inRange3 = LessThan(24);
        inRange3.in[0] <== 65535;
        inRange3.in[1] <== valueLen3;
        valid3 <== checkFirstByte3.out * inRange3.out;

        validVar += valid3; 
        prefixLenVar += 4 * valid3;
        finalValueLen3 <== finalValueLen2+ valueLen3 * valid3;
        valueLenVar = finalValueLen3;
    }
    // We could add more here, but that's probably enough for now

    component prefixShifted, valueShifted, allShifted;
    if (getField == 0) {
        for (var i = 0; i < stringMaxLen; i++) {
            out[i] <== 0;
        }
        allShifted = ShiftLeft(dataMaxLen, stringMinLen + minPrefixLength, stringMaxLen + maxPrefixLength);
        for (var i = 0; i < dataMaxLen; i++) {
            allShifted.data[i] <== data[i];
        }
        allShifted.shift <== prefixLenVar + valueLenVar;
        for (var i = 0; i < dataMaxLen; i++) {
            shiftedData[i] <== allShifted.out[i];
        }
    } else {
        prefixShifted = ShiftLeft(dataMaxLen, minPrefixLength, maxPrefixLength);
        for (var i = 0; i < dataMaxLen; i++) {
            prefixShifted.data[i] <== data[i];
        }
        prefixShifted.shift <== prefixLenVar;
        for (var i = 0; i < stringMaxLen; i++) {
            out[i] <== prefixShifted.out[i];
        }
        valueShifted = ShiftLeft(dataMaxLen, stringMinLen, stringMaxLen);
        for (var i = 0; i < dataMaxLen; i++) {
            valueShifted.data[i] <== prefixShifted.out[i];
        }
        valueShifted.shift <== valueLenVar;

        for (var i = 0; i < dataMaxLen; i++) {
            shiftedData[i] <== valueShifted.out[i];
        }
    }
    valid <== validVar;
    prefixLen <== prefixLenVar;
    valueLen <== valueLenVar;
}
