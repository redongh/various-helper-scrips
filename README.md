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

#### advanced configuration options
* blocksize  
  to change the blocksize (default: 64k) used, alter the value assigned to _BLKSZ_ at the beginning of the script.
  
* offset/resume  
  to start at a different offset from the beginning (default: 0) e.g. for resuming an aborted run, alter the value assigned to _BLKCNTR_ at the beginning of the script. this value is specified in number of blocks with the underlying blocksize being whatever is defined for _BLKSZ_.  
  so in case the offset should be 1 GiB (= 1024 * 1024 * 1024 bytes = 1073741824 bytes) from the start of the blockdevice and the default blocksize of 64 KiB (= 65536 bytes) is being used, one should specify a number of ( 1073741824 / 65536 ) - 1 = 16383.

of course, use with CAUTION and on your very own risk, this script WILL WIPE THE BLOCKDEVICE SPECIFIED, may contain bugs and might have other undesireable side effects if not used correctly!

### test-hashcat-truecrypt.sh
quick test to see if all supported modes work correctly. this was thrown together when commiting [bug 456](https://github.com/hashcat/hashcat/issues/456) to hashcat for easier verification.

works nicely in conjunction with the [*.tc -examples for modes 6211-6241 provided in the hashcat-wiki](https://hashcat.net/wiki/doku.php?id=example_hashes).

**note:** this shellscript calls hashcat *(after specifying the path to your hashcat-binary)* with ./passwordlist as input dictionary, so make sure this file exists and contains a valid password for your .tc files to test against.

if using the examples from hashcat-wiki, the password is *hashcat*.
