#!/usr/bin/env python
# -*- coding: utf-8 -*
"""
:authors: Yang Honggang <rtlinux@163.com>
"""
# vi:set tw=0 ts=4 sw=4 nowrap fdm=indent

import json
import operator
import subprocess
import sys
from threading import Timer

class CMD(object):
    """
    Execute local shell cmd with timeout.
    """
    ret = None

    def __init__(self):
        super(self.__class__, self).__init__()

    def __kill__(self, popen):

        out = popen.poll()
        if out is None:
            popen.kill()
            self.ret = -1

    def run(self, cmd, timeout=120):
        """
        @cmd - local shell cmd
        @timeout - timeout in seconds
        """
        p = subprocess.Popen(cmd, shell=True, stdin=subprocess.PIPE,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        mon_timer = Timer(timeout, self.__kill__, [p])
        try:
            mon_timer.start()
            out, err = p.communicate()
            mon_timer.cancel()
        except Exception as e:
            return (-1, '', '"%s" error' % (cmd))

        if self.ret == -1:
            err = '"%s" timeout' % (cmd)
            out = ''

        return (p.returncode, out, err)

if __name__ == '__main__':

    if len(sys.argv) < 2:
        print 'usage: {} POOL_NAME'.format(sys.argv[0])
        exit(-1)

    pool = sys.argv[1]
    mycmd = CMD()
    ret, out, err = mycmd.run('ceph pg ls-by-pool {} -f json'.format(pool), timeout=60)
    pgs = json.JSONDecoder().decode(out)
    osd_count = {}
    for pg in pgs:
        osds=pg['acting']
        for osd in osds:
            if osd in osd_count:
                osd_count[osd] += 1
            else:
                osd_count[osd] = 1

    osds_sorted = sorted(osd_count.items(), key=operator.itemgetter(0))
    print 'osd\t pgs'
    max = 0
    min = 65535000
    avg = 0
    for osd in osds_sorted:
        if osd[1] > max:
            max = osd[1]
        if osd[1] < min:
            min = osd[1]
        avg += osd[1]
        print '{}\t{}'.format(osd[0], osd[1])
    print 'max: {}, min: {}, avg: {}/{}={}'.format(max, min,
        avg, len(osds_sorted), float(avg)/len(osds_sorted))
