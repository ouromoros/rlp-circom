## rlp-circom

The result inherits a number of of design choices and optimization tricks from [Yi Sun's reference implementation](https://github.com/yi-sun/zk-attestor/blob/master/circuits/rlp.circom). There are a number of key differences:

1. Operates on byte arrays instead of hex arrays.

  This reduces the size of field array to half the size, is more intuitive and drastically reduces the constraint number to half of the original number.

2. Adds support for nested list structure rather than just flat lists.

We also did a number of other optimization techniques.


### Build

```
npm i
```

### Test

```
npm test
```