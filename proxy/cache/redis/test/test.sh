#!/bin/bash

stamp=`date +%Y%m%d%H%M%S`

#basic test
echo "Run basic tests ..."

time1=`date +%s`

curl "http://127.0.0.1:8080/redis/test/basic" > test/log/basic_$stamp.log 2>&1

time2=`date +%s`
elapse=`expr $time2 - $time1`

grep "All basic tests have succeeded" test/log/basic_$stamp.log > /dev/null 2>&1
if [ $? -ne 0 ] ; then
    echo "basic test failed, try to find cause from test/log/basic_$stamp.log"
    return 1
else
    echo "Basic test succeeded. elapse=$elapse"
fi

#concurrent test
echo "Run concurrent tests ..."
redis-cli -c -p 7000 set foobar 0 > /dev/null 2>&1
if [ $? -ne 0 ] ; then
    echo "failed to reset foobar"
    return 1
fi

steps=123456
total=`expr $steps \* 9`

time1=`date +%s`

curl -s "http://127.0.0.1:8080/redis/test/concurrent?c=$steps" > /dev/null 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent?c=$steps" > /dev/null 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent?c=$steps" > /dev/null 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent?c=$steps" > /dev/null 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent?c=$steps" > /dev/null 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent?c=$steps" > /dev/null 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent?c=$steps" > /dev/null 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent?c=$steps" > /dev/null 2>&1 &
curl -s "http://127.0.0.1:8080/redis/test/concurrent?c=$steps" > /dev/null 2>&1 &

wait

time2=`date +%s`
elapse=`expr $time2 - $time1`

ret=`redis-cli -c -p 7000 get foobar 2>/dev/null`

if [ $ret -ne $total ] ; then
    echo "concurrent test failed. expected result is 1111104, but actual is $ret"
    return 1
else
    echo "Concurrent test succeeded. elapse=$elapse"
fi
