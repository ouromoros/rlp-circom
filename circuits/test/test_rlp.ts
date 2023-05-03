// @ts-ignore
import path from "path";

import { expect, assert } from 'chai';
const circom_tester = require('circom_tester');
const wasm_tester = circom_tester.wasm;

import { ethers } from "ethers";
import RLP from 'rlp';
import { get_bsc_message_rlp, headers } from './bsc';


describe("RLP decoding", function () {
    this.timeout(60 * 1000);

    let circuit: any;
    before(async function () {
        console.log("Initialize the circuit test_rlp with wasm tester");
        circuit = await wasm_tester(path.join(__dirname, "circuits", "test_bsc_header.circom"));
        await circuit.loadConstraints();
        console.log("constraints: " + circuit.constraints.length);
    });
    function uint8ArrayToHexString(uint8Array: any) {
        let hexString = "";
        for (let i = 0; i < uint8Array.length; i++) {
          const hex = uint8Array[i].toString(16);
          hexString += hex.length === 1 ? "0" + hex : hex;
        }
        return hexString;
      }

    var test_rlp_decode = function (header: any) {
        console.log("Start test_rlp_decode");
        let chainId = 56;
        let encoded = get_bsc_message_rlp(header, chainId);
        let pubAddress = header.coinbase;

        let RLP_CIRCUIT_MAX_INPUT_LEN = 1075;
        // encoded = smallRLP(header);
        // encoded header -> array of bigint
        let input = new Array(RLP_CIRCUIT_MAX_INPUT_LEN);
        for (let i = 0; i < encoded.length; i++) {
            input[i] = BigInt(encoded[i]);
        }

        let sarr = ""
        for (let i = 0; i < encoded.length; i++) {
            sarr += encoded[i] + ", "
        }
        console.log(sarr);
        console.log(uint8ArrayToHexString(encoded));
        for (let i = encoded.length; i < RLP_CIRCUIT_MAX_INPUT_LEN; i++) {
            input[i] = 0n;
        }

        it('Testing bsc header, number ' + header.number, async function() {
            let witness = await circuit.calculateWitness(
                {
                    "data": input
                });

            // account address == coinbase
            expect(witness[1]).to.equal(BigInt(header.coinbase));
            // chain ID
            expect(witness[2]).to.equal(BigInt(chainId));
            // block number
            expect(witness[3]).to.equal(BigInt(header.number));
            await circuit.checkConstraints(witness);
        });
    }
    
    headers.forEach(test_rlp_decode);
});