// @ts-ignore
import path from "path";
import RLP from 'rlp';
const circom_tester = require('circom_tester');
const wasm_tester = circom_tester.wasm;

describe("RLP decoding", function () {
    this.timeout(120 * 1000);

    let circuit: any;
    before(async function () {
        console.log("Initialize the circuit test_rlp with wasm tester");
        circuit = await wasm_tester(path.join(__dirname, "circuits", "test_string_prefix.circom"));
        await circuit.loadConstraints();
        console.log("constraints: " + circuit.constraints.length);
    });

    async function testPrefix(data: string, expectedValueLen: number, expectedPrefixLen: number) {
        const encoded = RLP.encode(data);
        const input = new Array(1000);
        for (let i = 0; i < encoded.length; i ++) {
            input[i] = BigInt(encoded[i]);
        }
        for (let i = encoded.length; i < 1000; i++) {
            input[i] = BigInt(0);
        }
        const witness = await circuit.calculateWitness({ data: input });
        await circuit.checkConstraints(witness);
        await circuit.assertOut(witness, { valueLen: expectedValueLen, prefixLen: expectedPrefixLen });
    }

    const testData: [string, string, number, number][] = [
        ["empty string", "", 0, 1],
        ["single byte", "a", 1, 0],
        ["length 55", "a".repeat(55), 55, 1],
        ["length 56", "a".repeat(56), 56, 2],
        ["length 255", "a".repeat(255), 255, 2],
        ["length 256", "a".repeat(256), 256, 3],
        // ["length 65535", "a".repeat(65535), 65535, 3],
        // ["length 65536", "a".repeat(65536), 65536, 4],
        // heap limit reached
        // ["length 16777215", 16777215, 16777215, 4],
    ];

    for (let i = 0; i < testData.length; i++) {
        const testCase = testData[i];
        it(testCase[0],  async () => await testPrefix(testCase[1], testCase[2], testCase[3]));
    }
});
