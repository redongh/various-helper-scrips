#!/usr/bin/env bash
##
##  WARNING: this script was thrown together quickly and hash not been tested very
## +thoroughly, use on your own risk!!!
##
##  synopsis: run hashcat on a series of truecrypt-containers (sector-pieces are 
## +sufficient) to verify certain modes are working correctly!
##
##  only containers (or pieces thereof) with extension '.tc' located in the scripts 
## +directory are processed.
##
##  before using the script, set the path to your hashcat-binary that you want to
##  run the test on in belows config-sections variable 'hcBinary'
##
##  to only run a subset of all available truecrypt modes modify 'hcModes' and the
## +corresponding descriptions in 'hcModeNames'
##
##  :version:   see $SCRIPTVERSION
##  :license:   distributed under the terms of the MIT-license model. for details
##             +see https://opensource.org/licenses/MIT .
##  :copyright: 2016 redongh (https://github.com/redongh)

SCRIPTVERSION="0.1.1 (16/08/15)"

## config-section start ##
tcSectorFolder='./'
hcBinary="/path/to/hashcat/binary/hashcat64.bin"

hcModes='6211 6212 6213 6221 6222 6223 6231 6232 6233 6241 6242 6243'
hcModeNames='RMd160_512b RMd160_1024b RMd160_1536b SHA512_512b SHA512_1024b SHA512_1536b Whrlp_512b Whrlp_1024b Whrlp_1536b RMd160Boot_512b RMd160Boot_1024b RMd160Boot_1536b'
## config-section end ##


## 'convert' to mode-string to array
hcModeA=( $hcModes )
hcModeNameA=( $hcModeNames )

## get list of tc-sectors to test
## below construct shamelessly taken from https://stackoverflow.com/a/1120952/294930
while IFS= read -r -u3 -d $'\0' file; do
 tcSectorA[i++]="$file"  # or however you want to process each file
done 3< <(find "$tcSectorFolder" -maxdepth 1  -type f -name '*.tc' -print0)

## get hashcat version
hcVersion=`eval ${hcBinary} --version`
echo "  found ${#tcSectorA[@]} tcSector-Files to test with ${#hcModeA[@]} modes in hashcat $hcVersion:"

## iterate over configured hcModes
for hcMode in $(seq 0 $((${#hcModeA[@]} - 1))); do
 echo "  ### testing tc-mode ${hcModeA[$hcMode]} (${hcModeNameA[$hcMode]})"

 ## iterate over the list of files found
 for tcSectorNum in $(seq 0 $((${#tcSectorA[@]} - 1))); do
  hcCall="${hcBinary} -m${hcModeA[$hcMode]} -a0 --quiet --session=test_${hcModeA[$hcMode]}_${tcSectorA[$tcSectorNum]:2} ${tcSectorA[$tcSectorNum]} ./passwordlist 2>&1 >/dev/null"
  eval $hcCall
  retVal=$?
  if [[ "$retVal" -gt 0 ]]; then
    echo -n "  -> FAIL"
  else
    echo -n "  -> OK  "
  fi
  echo "  (${tcSectorA[$tcSectorNum]:2})"
 done
 echo ''
done
