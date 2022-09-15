## various-helper-scrips
somehow useful little helpers for here and there

### zero_nonzero_blocks_of_dev.sh
bash script depending on `dcfldd` for zeroing only blocks (configurable, default 64k) that contain something else than zeroes.  
this can be handy when working with flash based media that would potentionally suffer (due to a limited number of writes to its cells) from entirely being overwritten often when not necessary but yet, a defined state of the underlying device is needed (zeroed in this case :smirk: ).

to achieve this, a quick md5-hash is generated from every block of the device specified and compared to the value of a block that only contains zeroes.

the script will perform a very quick verification of the some of the last blocks that have been zeroed after the process has been finished as some kind of sanity check. this brief check CANNOT GUARANTEE THAT ALL OF THE BLOCKS HAVE SUCCESSFULLY OVERWRITTEN but gives some kind of indication, so please don't fully rely on it in cases where one needs to be 100% sure that the entire device only contains zeros and run your own verification for this. however, in my personal observation, the cances that non-zero data will remain unnoticed are quite small.

#### usage
invoke with superuser-rights and specify the target:  
`sudo ./zero_nonzero_blocks_of_dev.sh /dev/<device-to-be-zeroed>`

use with CAUTION and on your own risk, this script WILL WIPE THE BLOCKDEVICE SPECIFIED!

### test-hashcat-truecrypt.sh
quick test to see if all supported modes work correctly. this was thrown together when commiting [bug 456](https://github.com/hashcat/hashcat/issues/456) to hashcat for easier verification.

works nicely in conjunction with the [*.tc -examples for modes 6211-6241 provided in the hashcat-wiki](https://hashcat.net/wiki/doku.php?id=example_hashes).

**note:** this shellscript calls hashcat *(after specifying the path to your hashcat-binary)* with ./passwordlist as input dictionary, so make sure this file exists and contains a valid password for your .tc files to test against.

if using the examples from hashcat-wiki, the password is *hashcat*.
