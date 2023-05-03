import { ethers } from "ethers";
import RLP from 'rlp';

const headers = [
    // https://bscscan.com/block/7706000
    {
        difficulty: 0x2,
        extra_data: '0xd883010100846765746888676f312e31352e35856c696e7578000000fc3ca6b72465176c461afb316ebc773c61faee85a6515daa295e26495cef6f69dfa69911d9d8e4f3bbadb89b29a97c6effb8a411dabc6adeefaa84f5067c8bbe2d4c407bbe49438ed859fe965b140dcf1aab71a93f349bbafec1551819b8be1efea2fc46ca749aa14430b3230294d12c6ab2aac5c2cd68e80b16b581685b1ded8013785d6623cc18d214320b6bb6475970f657164e5b75689b64b7fd1fa275f334f28e1872b61c6014342d914470ec7ac2975be345796c2b7ae2f5b9e386cd1b50a4550696d957cb4900f03a8b6c8fd93d6f4cea42bbb345dbc6f0dfdb5bec739bb832254baf4e8b4cc26bd2b52b31389b56e98b9f8ccdafcc39f3c7d6ebf637c9151673cbc36b88a6f79b60359f141df90a0c745125b131caaffd12b8f7166496996a7da21cf1f1b04d9b3e26a3d077be807dddb074639cd9fa61b47676c064fc50d62cce2fd7544e0b2cc94692d4a704debef7bcb61328e2d3a739effcd3a99387d015e260eefac72ebea1e9ae3261a475a27bb1028f140bc2a7c843318afdea0a6e3c511bbd10f4519ece37dc24887e11b55dee226379db83cffc681495730c11fdde79ba4c0c675b589d9452d45327429ff925359ca25b1cc0245ffb869dbbcffb5a0d3c72f103a1dcb28b105926c636747dbc265f8dda0090784be3febffdd7909aa6f416d200',
        gas_limit: 0x391a17f,
        gas_used: 0x151a7b2,
        log_bloom: '0x4f7a466ebd89d672e9d73378d03b85204720e75e9f9fae20b14a6c5faf1ca5f8dd50d5b1077036e1596ef22860dca322ddd28cc18be6b1638e5bbddd76251bde57fc9d06a7421b5b5d0d88bcb9b920adeed3dbb09fd55b16add5f588deb6bcf64bbd59bfab4b82517a1c8fc342233ba17a394a6dc5afbfd0acfc443a4472212640cf294f9bd864a4ac85465edaea789a007e7f17c231c4ae790e2ced62eaef10835c4864c7e5b64ad9f511def73a0762450659825f60ceb48c9e88b6e77584816a2eb57fdaba54b71d785c8b85de3386e544ccf213ecdc942ef0193afae9ecee93ff04ff9016e06a03393d4d8ae14a250c9dd71bf09fee6de26e54f405d947e1',
        coinbase: '0x72b61c6014342d914470eC7aC2975bE345796c2b',
        mix_digest: '0x0000000000000000000000000000000000000000000000000000000000000000',
        nonce: '0x0000000000000000',
        number: 0x759590,
        msg_hash: '0x2f17cec57f93ee1bdd87ef0f3ecf732d40d6583ad3d9d243569b203bddf9537b',
        parent_hash: '0x898c926e404409d6151d0e0ea156770fdaa2b31f8115b5f20bcb1b6cb4dc34c3',
        receipts_root: '0x04aea8f3d2471b7ae64bce5dde7bb8eafa4cf73c65eab5cc049f92b3fda65dcc',
        uncle_hash: '0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347',
        state_root: '0x5d03a66ae7fdcc6bff51e4c0cf40c6ec2d291090bddd9073ca4203d84b099bb9',
        timestamp: 0x60ac738f,
        transactions_root: '0xb3db66bc49eac913dbdbe8aeaaee891762a6c5c28990c3f5f161726a8cb1c41d'
    }
];

function get_bsc_message_rlp(header: any, chainId: number) {
    let list: any[] = [];

    list.push(chainId);
    list.push(ethers.utils.solidityPack(['bytes32'], [header.parent_hash]));
    list.push(ethers.utils.solidityPack(['bytes32'], [header.uncle_hash]));
    list.push(ethers.utils.solidityPack(['address'], [header.coinbase]));
    list.push(ethers.utils.solidityPack(['bytes32'], [header.state_root]));
    list.push(ethers.utils.solidityPack(['bytes32'], [header.transactions_root]));
    list.push(ethers.utils.solidityPack(['bytes32'], [header.receipts_root]));
    list.push(ethers.utils.solidityPack(['bytes'], [header.log_bloom]));

    list.push(header.difficulty);
    list.push(header.number);
    list.push(header.gas_limit);
    list.push(header.gas_used);
    list.push(header.timestamp);
    list.push(header.extra_data.substring(0, header.extra_data.length - 65 * 2));
    // list.push(ethers.utils.solidityPack(['bytes'], [header.extra_data.substring(header.extra_data.length - 65*2)]));
    
    list.push(ethers.utils.solidityPack(['bytes32'], [header.mix_digest]));
    list.push(ethers.utils.solidityPack(['bytes8'], [header.nonce]));
    let encoded = RLP.encode(list);
    let encodedStr = Buffer.from(encoded).toString('hex');
    // console.log('RLP encoded value is ', encodedStr);
    return encoded;
}


export {
    get_bsc_message_rlp,
    headers
};