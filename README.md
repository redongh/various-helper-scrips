## various-helper-scrips
somehow useful little helpers for here and there

### test-hashcat-truecrypt.sh
quick test to see if all supported modes work correctly. this was thrown together when commiting [bug 456](https://github.com/hashcat/hashcat/issues/456) to hashcat for easier verification.

works nicely in conjunction with the [*.tc -examples for modes 6211-6241 provided in the hashcat-wiki](https://hashcat.net/wiki/doku.php?id=example_hashes).

**note:** this shellscript calls hashcat *(after specifying the path to your hashcat-binary)* with ./passwordlist as input dictionary, so make sure this file exists and contains a valid password for your .tc files to test against.

if using the examples from hashcat-wiki, the password is *hashcat*.
