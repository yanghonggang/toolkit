#!/bin/bash

POOL="default.rgw.buckets.data"
COS_BASE="/home/yhg/rgw/cos"
COS_CLI="${COS_BASE}/cli.sh"
COS_CONF="${COS_BASE}/tier/"
DRY_RUN="true"

function init_tier {
  ceph osd tier cache-mode $POOL local --yes-i-really-mean-it
  ceph osd pool set $POOL hit_set_type bloom                                                     
  ceph osd pool set $POOL hit_set_count 4 
  ceph osd pool set $POOL hit_set_period 60 
  ceph osd pool set $POOL hit_set_grade_decay_rate 20                                            
  ceph osd pool set $POOL hit_set_search_last_n 1                                                
  ceph osd pool set $POOL min_read_recency_for_promote 3
  ceph osd pool set $POOL min_write_recency_for_promote 3                                      
  ceph osd pool set $POOL cache_local_mode_default_fast 1
}

function cleanup_data_pool {
  local tmp_file="/tmp/xxxyyzz"
  rados -p $POOL ls > $tmp_file
  i=0
  STEP=20
  while read o
  do
    {
      rados -p $POOL rm $o
    } &
    ((i=($i+1)%$STEP))
    if [ $i -eq 0 ]; then
      wait
    fi
  done < $tmp_file
}

function wait_until_0_active()
{
  while true
  do
    bash ${COS_CLI} info 2>/dev/null
    num_active=$(bash ${COS_CLI} info 2>/dev/null | grep active | awk '{printf $2}')
    if [ $num_active == "0" ];then
      echo "cosbench task finished"
      return
    fi
    sleep 60
  done
}

############ main #####

[ $DRY_RUN != "true" ] && init_tier

tests=`ls ${COS_CONF}`
for test in $tests
do
  echo ">>> tier bench for $test"
  [ $DRY_RUN != "true" ] && bash ${COS_CLI} submit ${COS_CONF}/$test
  wait_until_0_active
  cleanup_data_pool
  echo ">>> tier bench for $test done"
done

[ $DRY_RUN != "true" ] && ceph osd tier cache-mode $POOL none --yes-i-really-mean-it

for test in $tests
do
  echo ">>> def bench for $test"
  [ $DRY_RUN != "true" ] && bash ${COS_CLI} submit ${COS_CONF}/$test
  wait_until_0_active
  cleanup_data_pool
  echo ">>> def bench for $test done"
done
