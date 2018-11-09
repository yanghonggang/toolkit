#!/bin/bash

POOL="rbd"
TIME=300
PGNUM=1

function set_cache_mode_fast() {
  ceph osd tier cache-mode ${POOL} local --yes-i-really-mean-it 
  ceph osd pool set ${POOL} hit_set_type bloom                             
  ceph osd pool set ${POOL} hit_set_count 4
  ceph osd pool set ${POOL} hit_set_period 120 
  ceph osd pool set ${POOL} hit_set_grade_decay_rate 20                                             
  ceph osd pool set ${POOL} hit_set_search_last_n 1
  ceph osd pool set ${POOL} min_read_recency_for_promote 2
  ceph osd pool set ${POOL} min_write_recency_for_promote 2
  ceph osd pool set ${POOL} cache_local_mode_default_fast 1
}

function set_cache_mode_none_and_demote_all() {
  ceph osd tier cache-mode ${POOL} none
  rados -p ${POOL} cache-demote-all > /dev/null 2>&1
}

# put objects background
function put_objs_bg() {
  rados bench -p ${POOL} -b 4K ${TIME} write --no-cleanup > /dev/null 2>&1
  touch stop_sw
}

function cache_mode_sw_bg {
  {
    while true
    do
      set_cache_mode_fast
      sleep 5
      set_cache_mode_none_and_demote_all
      [ -f stop_sw ] && break
      sleep 5
    done
  } &
}

##### main
rm -rf stop_sw
rados rmpool ${POOL} ${POOL} --yes-i-really-really-mean-it
ceph osd pool create ${POOL} ${PGNUM} ${PGNUM} replicated
cache_mode_sw_bg
put_objs_bg
wait
ceph osd deep-scrub 0
