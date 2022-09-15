#!/usr/bin/env bash
## check if all blocks (size determined by BLKSZ) contain zeros and
##  OVERWRITE non-zero blocks with zeros 
## dependencies: dcfldd
## license:      EUPL

## meta start
SCRIPT_VERSION="0.1.5 (15/09/22)"
SCRIPT_AUTHOR="redongh (https://github.com/redongh)"
## meta end

BLKDEV=''    ## target block device
BLKSZ='64'   ## blocksize in KiB (kibibytes → times 1024 !)
#BLKSZ='2048'
ZEROBLKHASH='fcd6bcb56c1689fcef28b57c22475bad'  ## pre-calculated for 64k zero block, other sizes will be dynamically calculated
LASTHASH=''  ## used as a variable to return a blocks hash
BLKCNTR=0
#BLKCNTR=61408	## set to any block number needed to resume aborted sessions
BLKCNTRNZ=0 ## number of non-zero blocks discovered
RETRCNTR=0  ## counter for total retries of failed blocks
PADDING=4  ## padding used for numbers in function overwrite_lastline
BLKCHKA=(0 1 2 3 4 5 6 7)   ## block numbers to be checked to be zero after finishing
SECONDS=0 # Reset BASH time counter 

print_walltime() {
  ## one-liner variant:
  #ELAPSED="Elapsed: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"
  ## multiline variant:
  RUNT_HRS=$((${SECONDS} / 3600))
  RUNT_MIN=$((${SECONDS} % 3600))
  RUNT_SEC=$((${RUNT_MIN} % 60 ))
  RUNT_MIN=$((${RUNT_MIN} / 60 ))

  printf "\n\nfinishing after handling %d blocks involving %d retries in" ${BLKCNTR} ${RETRCNTR}

  if [ ${RUNT_HRS} -gt 0 ]; then
    LC_NUMERIC=C printf " %02dh %02dm %02ds.\n\n" ${RUNT_HRS} ${RUNT_MIN} ${RUNT_SEC}
  elif [ ${RUNT_MIN} -gt 0 ]; then
    LC_NUMERIC=C printf " %02dm %02ds.\n\n" ${RUNT_MIN} ${RUNT_SEC}
  else
    LC_NUMERIC=C printf " %02ds.\n\n" ${RUNT_SEC}
  fi
}

## redirect messages to stderr
echoerr() { 
  >&2 printf "\n\n%s\n" "$*"  ## this would also work if strings to print contain '-ne' or similar
#  >&2 echo "$@"           ## this would eat '-ne' or similar
}

## see https://stackoverflow.com/a/51858404 for further explanantion of the escape-sequences used
overwrite_lastline() { 
  LC_NUMERIC=C printf "\r\033[1A\033[0K\n current block: %0${PADDING}d   NONzero blocks: %0${PADDING}d   zero blocks: %0${PADDING}d" "$1" "$2" "$3"
}

update_lasthash() {
  local retr=3
  while [ $retr -gt 0 ]; do
    RAWOUT=`dcfldd if=${BLKDEV} bs=${BLKSZ}k count=1 skip=${BLKCNTR} hash=md5 totalhashformat='total_#algorithm#:#hash#:' of=/dev/null status=off 2>&1 | head -n 1`
    RETVAL=$?
    if [ ${RETVAL} -ne 0 ]; then
      sleep ".$((6 / $retr))"
      ((--retr))
      ((++RETRCNTR))
    else
      [[ "${RAWOUT}" =~ total_[^:]*:([^:]*): ]]  ## match the hash-value itself
      LASTHASH="${BASH_REMATCH[1]}"   ## set result to global var
      return 0
    fi
  done
  echoerr "error: dcfldd failed 3 times to read block ${BLKCNTR} and yielding:\n \"${RAWOUT}\""
  return 5
}

## check if executed as superuser/root
if [ "$EUID" -ne 0 ]; then
  echoerr "error: need to be root!"
  exit 1
fi

## check if dcfldd is available / in path
if [ ! $(type -P 'dcfldd') ]; then
  echoerr "error: dcfldd was not found, make sure it is available and included in PATH!"
  exit 1
fi

## check we got a device present on the system as arg#1
if [ $# != 1 ]; then
  echoerr "usage: $0 <device-to-zero>"
  exit 1
fi

## check param starts with /dev/
if [[ ! "$1" =~ ^/dev/.* ]]; then
  echoerr "error: param \"$1\" seems invalid (should start with '/dev/ ...')."
  exit 1
fi

## check if specified device is present on system
if [ ! $(lsblk "${1}" 1>/dev/null 2>&1) ]; then
  echoerr "error: specified device \"$1\" not present on system."
  exit 1
else
  BLKDEV="${1}"
fi

read -p "locating AND OVERWRITING nonzero blocks on device '${BLKDEV}', do you want to proceed? [y/N]: " confirm && [[ "${confirm}" == [yY] || "${confirm}" == [yY][eE][sS] ]] || { echo -e "\n\naborting..." && exit 2; }

set -o pipefail ## forward status of piped commands
stty -echoctl   ## hide ^C from appearing on terminal
trap print_walltime EXIT

## get a reference hash and file for blocksizes != 64k
if [ '${BLKSZ}k' != '64k' ]; then
  RAWOUT=`dcfldd pattern=00000000 bs=${BLKSZ}k count=1 hash=md5 totalhashformat='total_#algorithm#:#hash#:' of=/tmp/zero_${BLKSZ}k.dd status=off 2>&1 | head -n 1`
  RETVAL=$?
  [ ${RETVAL} -ne 0 ] && { echoerr 'error: failed to create reference zero-file for comparison, aborting!'; exit 3; }
  [[ ${RAWOUT} =~ total_[^:]*:([^:]*): ]]  ## match the hash-value itself
  ZEROBLKHASH=${BASH_REMATCH[1]}
  echo -e "\ndetermined md5-hash of '${ZEROBLKHASH}' for a zero block of size ${BLKSZ}k."
  rm /tmp/zero_${BLKSZ}k.dd
fi

## get size of block device in bytes
SIZEB=`blockdev --getsize64 ${BLKDEV}`
RETVAL=$?
[ ${RETVAL} -ne 0 ] && { echoerr 'error: failed to determine size of ${BLKDEV}, aborting!'; exit 4; }
## get remainder of device-size / blocksize
REMAINDERSIZEB=$((SIZEB % (BLKSZ*1024)))
NUMBEROFBLOCKS=$((SIZEB / (BLKSZ*1024)))
PADDING=${#NUMBEROFBLOCKS}

echo -e "block-device ${BLKDEV} appears to consist of ${NUMBEROFBLOCKS} blocks of size ${BLKSZ}k\n plus a remainder of ${REMAINDERSIZEB} bytes.\n"

while :; do
  
  update_lasthash || { echoerr "error: aborting on block ${BLKCNTR}!"; exit 5; }
  
  if [[ "${ZEROBLKHASH}" != "${LASTHASH}" ]]; then
    sleep .015   ## prevent errors that seem to occur if there is no artifical delay
    ## perform zeroing of the current block
    RAWOUT=`dcfldd pattern=00000000 bs=${BLKSZ}k seek=${BLKCNTR} count=1 of=${BLKDEV} status=off 2>&1`
    ## add the blocknumber to the array of blocks to be checked on a final run
    BLKCHKA[$((${BLKCNTR}%8))]=${BLKCNTR}
    #LC_NUMERIC=C printf "\nblk%03d: %s" "${BLKCNTR}" "${LASTHASH}"   ## debug-code
    ((++BLKCNTRNZ))
  #else
    #LC_NUMERIC=C printf "\nblk%03d: %s (zero)" "${BLKCNTR}" "${ZEROBLKHASH}"   ## debug-code
  fi
  
  overwrite_lastline "${BLKCNTR}" "${BLKCNTRNZ}" "$((${BLKCNTR}-${BLKCNTRNZ}))"
  ((++BLKCNTR))
#  [ ${BLKCNTR} -gt 7 ] && exit 255  ## premature exit for testing/dev
  if [ ${BLKCNTR} -eq ${NUMBEROFBLOCKS} ]; then
    echo -e '\n'
    if [ ${REMAINDERSIZEB} -ne 0 ]; then
      if [ $((${REMAINDERSIZEB} % 512)) -ne 0 ]; then
        echoerr "warning: remaining bytes of blockdevice ${BLKDEV} are not a multiple of 512b, therefore some final bytes may not be zero! please check and report if this should indeed be the case."
      fi
      ## zero remainding block without checking if zero or not
      RAWOUT=`dcfldd pattern=00000000 bs=512 seek=$((${BLKCNTR}*${BLKSZ}*2)) of=${BLKDEV} status=off 2>&1`
      echo -e "\n zeroing of ${REMAINDERSIZEB} remaining bytes also done."
      ((BLKCNTR--))
    fi
    
    STOREBLKCNTR=${BLKCNTR}   ## backup
    ## perform verification of blocks with block-numbers stored in BLKCHKA
    for VERIFYBLKNUM in "${BLKCHKA[@]}"; do
      BLKCNTR=${VERIFYBLKNUM}
      echo -n " verifying block ${BLKCNTR} ... "
      update_lasthash || { echoerr "error: aborting on block ${BLKCNTR}!"; exit 5; }
      [ "${ZEROBLKHASH}" == "${LASTHASH}" ] && echo 'ok.' || echoerr "error: block should have been zeroed but it still doesn't match the expected hash, so something is severely wrong! better check the health status on the device!"
    done
    BLKCNTR=${STOREBLKCNTR}   ## restore
    exit 0
  fi

  sleep .01   ## prevent read-errors that seem to occur if there is no artifical delay
done
