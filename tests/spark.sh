#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2015-11-11 19:39:17 +0000 (Wed, 11 Nov 2015)
#
#  https://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  http://www.linkedin.com/in/harisekhon
#

set -eu
srcdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$srcdir/";

. ./travis.sh

echo "
# ============================================================================ #
#                               S p a r k
# ============================================================================ #
"

export SPARK_HOST="${SPARK_HOST:-localhost}"

SPARK_VERSION=1.5.2
BIN="bin-hadoop2.6"
SPARK="spark-$SPARK_VERSION-$BIN"
TAR="$SPARK.tgz"

if ! [ -e "$TAR" ]; then
    echo "fetching Spark tarball '$TAR'"
    wget "http://www.us.apache.org/dist/spark/spark-$SPARK_VERSION/$TAR"
    echo
fi

if ! [ -d "$SPARK" ]; then
    echo "unpacking Spark"
    tar zxf "$TAR"
    echo
fi

if ps -ef | grep -qi "org.apache.spark.deploy.master.Maste[r]"; then
    echo "killing already running Spark Master"
    ps -ef | grep -i "org.apache.spark.deploy.master.Maste[r]" | awk '{print $2}' | xargs kill
    echo "waiting 10 secs for old master to shut down"
    sleep 10;
fi
"$SPARK/sbin/start-master.sh" &
echo "waiting 10 secs for new master to start up"
sleep 10
if ps -ef | grep -qi "org.apache.spark.deploy.worker.Worke[r]"; then
    echo "killing already running Spark Worker"
    ps -ef | grep -i "org.apache.spark.deploy.worker.Worke[r]" | awk '{print $2}' | xargs kill
    echo "waiting 10 secs for old worker to shut down"
    sleep 10;
fi
"$SPARK/sbin/start-slave.sh" $(hostname -f):7077 &
echo "waiting 15 secs for new worker to start up"
sleep 15

cd "$srcdir/..";
echo
hr
$perl -T $I_lib ./check_spark_cluster.pl -c 1: -vvv
hr
$perl -T $I_lib ./check_spark_cluster_dead_workers.pl -w 1 -c 1 -vvv
hr
$perl -T $I_lib ./check_spark_cluster_memory.pl -w 80 -c 90 -vvv
hr
$perl -T $I_lib ./check_spark_worker.pl -w 80 -c 90 -vvv
hr

echo; echo
