#!/bin/bash

logdir=`dirname $0`/log

stamp=`date +%Y%m%d%H%M%S`

#basic test
echo "Run basic tests ..."

time1=`date +%s`

curl "http://127.0.0.1:8080/redis/test/basic" > $logdir/basic_$stamp.log 2>&1

time2=`date +%s`
elapse=`expr $time2 - $time1`

grep "All basic tests have succeeded" $logdir/basic_$stamp.log > /dev/null 2>&1
if [ $? -ne 0 ] ; then
    echo "basic test failed, try to find cause from $logdir/basic_$stamp.log"
    exit 1
else
    echo "Basic test succeeded. elapse=$elapse"
fi

#concurrent test
echo "Run concurrent tests ..."
redis-cli -c -p 7000 set foobar 0 > /dev/null 2>&1
if [ $? -ne 0 ] ; then
    echo "failed to reset foobar"
    exit 1
fi

steps=123456
total=`expr $steps \* 9`

time1=`date +%s`

curl -s "http://127.0.0.1:8080/redis/test/concurrent1?c=$steps" > $logdir/concurrent1_$stamp.log 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent1?c=$steps" > $logdir/concurrent2_$stamp.log 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent1?c=$steps" > $logdir/concurrent3_$stamp.log 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent2?c=$steps" > $logdir/concurrent4_$stamp.log 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent2?c=$steps" > $logdir/concurrent5_$stamp.log 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent2?c=$steps" > $logdir/concurrent6_$stamp.log 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent1?c=$steps" > $logdir/concurrent7_$stamp.log 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent2?c=$steps" > $logdir/concurrent8_$stamp.log 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent1?c=$steps" > $logdir/concurrent9_$stamp.log 2>&1 &

wait

time2=`date +%s`
elapse=`expr $time2 - $time1`

ret=`redis-cli -c -p 7000 get foobar 2>/dev/null`

if [ $ret -ne $total ] ; then
    echo "concurrent test failed. expected result is 1111104, but actual is $ret"
    exit 1
else
    echo "Concurrent test succeeded. elapse=$elapse"
fi

#consistency test
# the idea is like this:
# when we run consistency.lua, we crash a master node and then restart it.
# During this period of time, many access errors will occur (because slotmap is
# outdated). The cluster will refresh the slotmap when too many errors have been
# found. So, after the last refresh, error numbers should stop increasing. 
# Thus, we find out the error numbers after the last refresh, and we find out
# the error numbers at the end. They should be equal to each other.
echo "Run consistency tests ..."

time1=`date +%s`
curl -s "http://127.0.0.1:8080/redis/test/consistency?round=100" > $logdir/consistency_$stamp.log 2>&1 &

sleep 1

#seletet a master node (not 7000) to kill
pid=`redis-cli -p 7000 cluster nodes | grep master | grep -v ":7000" | cut -d ' ' -f 2 | cut -d ':' -f 2 | head -1`

#kill the selected master node
redis-cli -p $pid  debug segfault > /dev/null 2>&1

sleep 1

#start the killed master node
redis-server /usr/local/etc/redis_$pid.conf

wait

time2=`date +%s`
elapse=`expr $time2 - $time1`

#find out the last refresh due to "too many errors"
line=`grep -n "too many errors.* need refresh" $logdir/consistency_$stamp.log | tail -1 | cut -d ':' -f 1`

if [ -z "$line" ] ; then
    line=`grep -n "WARNING: failed to get a sock from queue" $logdir/consistency_$stamp.log | tail -1 | cut -d ':' -f 1`
fi

if [ -z "$line" ] ; then
    line=`grep -n "refresh success" $logdir/consistency_$stamp.log | tail -1 | cut -d ':' -f 1`
fi

if [ -z "$line" ] ; then
    line=0
fi

#skip every thing before last refresh, and find out the statistics after last
#refresh
sed -e "1,$line d" $logdir/consistency_$stamp.log > /tmp/consistency_$stamp.log

sed -i -e '1,/======================/ d' /tmp/consistency_$stamp.log

#well, discard 1 more, there will be some more errors (not very much) right 
#after the refresh.
sed -i -e '1,/======================/ d' /tmp/consistency_$stamp.log

reads=`head -n 6 /tmp/consistency_$stamp.log | grep "Num Read" | cut -d ":" -f 2`
writes=`head -n 6 /tmp/consistency_$stamp.log | grep "Num Write" | cut -d ":" -f 2`
rfails=`head -n 6 /tmp/consistency_$stamp.log | grep "Read Fail" | cut -d ":" -f 2`
wfails=`head -n 6 /tmp/consistency_$stamp.log | grep "Write Fail" | cut -d ":" -f 2`
wlosts=`head -n 6 /tmp/consistency_$stamp.log | grep "Lost Write" | cut -d ":" -f 2`
wnoack=`head -n 6 /tmp/consistency_$stamp.log | grep "Un-acked Write" | cut -d ":" -f 2`

reads1=`tail -n 6 /tmp/consistency_$stamp.log | grep "Num Read" | cut -d ":" -f 2`
writes1=`tail -n 6 /tmp/consistency_$stamp.log | grep "Num Write" | cut -d ":" -f 2`
rfails1=`tail -n 6 /tmp/consistency_$stamp.log | grep "Read Fail" | cut -d ":" -f 2`
wfails1=`tail -n 6 /tmp/consistency_$stamp.log | grep "Write Fail" | cut -d ":" -f 2`
wlosts1=`tail -n 6 /tmp/consistency_$stamp.log | grep "Lost Write" | cut -d ":" -f 2`
wnoack1=`tail -n 6 /tmp/consistency_$stamp.log | grep "Un-acked Write" | cut -d ":" -f 2`

if [[ $reads1 -gt 0 ]] &&
   [[ $writes1 -eq $reads1 ]] && 
   [[ $rfails1 -eq $rfails ]] &&  #read error number should be equal
   [[ $wfails1 -eq $wfails ]] &&  #write error number should be equal
   [[ $wlosts1 -eq 0 ]] &&        #lost writes should be 0
   [[ $wnoack1 -eq 0 ]]           #write with no ack should be 0
then
    echo "Consistency test succeeded. elapse=$elapse"
else
    echo "Consistency test failed:"
    echo "Statistics after last refresh"
    head -n 6 /tmp/consistency_$stamp.log 
    echo "Statistics at last"
    tail -n 6 /tmp/consistency_$stamp.log 
fi

rm -f /tmp/consistency_$stamp.log
