#!/bin/bash

POOL="rbd"
HOSTS="umstor001 umstor002"
SIZE="500G"
DISK="disk0"
RTIME="600"

function drop_cache {
  for h in $HOSTS
  do
    {
      ssh -n $h "sync && echo 3 > /proc/sys/vm/drop_caches"
    } &
  done
  wait
}

function prepare_disk {
  rbd -p $POOL remove ${DISK}
  rbd -p $POOL create --image-feature layering --size $SIZE ${DISK}
  POOL=$POOL DISK=$DISK fio init-disk.fio > /dev/null 
}

function init_tier {
  ceph osd tier cache-mode $POOL local --yes-i-really-mean-it
  ceph osd pool set $POOL hit_set_type bloom                                                     
  ceph osd pool set $POOL hit_set_count 4 
  ceph osd pool set $POOL hit_set_period 60 
  ceph osd pool set $POOL hit_set_grade_decay_rate 20                                            
  ceph osd pool set $POOL hit_set_search_last_n 1                                                
  ceph osd pool set $POOL min_read_recency_for_promote 3
  ceph osd pool set $POOL min_write_recency_for_promote 3                                      
  ceph osd pool set $POOL cache_local_mode_default_fast 0
}

######## main #########
prepare_disk
op_list=`ls fios`
mkdir -p logs/{tier,def}

# with tier
for op in $op_list
do
  init_tier
  drop_cache
  echo ">>> tier $op begin"
  RTIME=$RTIME POOL=$POOL DISK=$DISK fio fios/$op > logs/tier/${op}.log 2>&1
  echo ">>> tier $op end"
  ceph osd tier cache-mode $POOL none --yes-i-really-mean-it
  rados -p $POOL cache-demote-all > /dev/null
done

# without tier
for op in $op_list
do
  drop_cache
  echo ">>> def $op begin"
  RTIME=$RTIME POOL=$POOL DISK=$DISK fio fios/$op > logs/def/${op}.log 2>&1
  echo ">>> def $op end"
done
