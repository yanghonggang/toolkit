#!/bin/bash

DEVS="sda sdb sdc sdd sde sdf nvme0n1"
TYPES="randread randwrite"
SIZES="4K 4M"
RTIME=60

for DEV in $DEVS
do
  for TYPE in $TYPES
  do
    for SIZE in $SIZES
    do
      echo ">>> bench $DEV $TYPE $SIZE begin"
      FILE=/dev/$DEV TYPE=$TYPE RTIME=$RTIME SIZE=$SIZE fio bench.fio
      echo ">>> bench $DEV $TYPE $SIZE end"
    done
  done
done
