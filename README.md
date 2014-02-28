Elasticsearch-zabbix
====================

Elasticsearch template and script for zabbix 2.0

Originally it was a fork of Elasticsearch template from zabbix-grab-bag but everything has been rewritten from scratch.

https://github.com/untergeek/zabbix-grab-bag


These are made available by me under an Apache 2.0 license.

http://www.apache.org/licenses/LICENSE-2.0.html

Introduction
============

Solution consists of **ESzabbix.rb** script which requires *elasticsearch* gem and *ESzabbix_templates*. The script is invoked as user parameter on ElasticSearch node, it caches the results for a specified cache_timeout (default 60s), this reduces the number of queries to ES.

How it works
=============

- Put ESzabbix.rb in /opt/zabbix/externalscripts/ in the zabbix node or wherever your external scripts are.

- Add zabbix user parameter to configuration.
        UserParameter=ESzabbix[*],_CHANGE_TO_YOUR_EXTDIR/ESzabbix.rb $1 $2


- Import ESzabbix_templates.xml to zabbix server

Specs
=====

The items here are for monitoring Elasticsearch (presumably for logstash).

The template xml file actually contains three templates:

1. Elasticsearch Node & Cache (which is for node-level monitoring)

2. Elasticsearch Cluster (cluster state, shard-level monitoring, record count, storage sizes, etc.)

3. Elasticsearch Service (ES service status)

4. Elasticsearch Health (JVM, openfiles descriptors)

There are triggers assigned for the cluster state:

0 = Green (OK)

1 = Yellow (Average, depends on "red")

2 = Red (High)

Cluster status should be aggregated item as max for a group of ElasticSearch nodes, because the script will report **Green** when the actual node's ES service is down. Using an aggregated item enables single triggering for the Cluster status.

Usage
=====

The scripts stores information retrieved from Elasticsearch and stored into hash, which has three metric sub-groups: **nodes_stats**, **nodes_info**, **health** . After metrics data has been retrieved from ES, the script gets value for the specified item.

For example, invoking script with two arguments `nodes_stats indices.docs.count`, the script will return value from nodes_stats with path *indices.docs.count*. This value concerns only to the node where script is invoked. Since indices metrics can be aggregated over the cluster, script supports **cluster:** prefix. Use `nodes_stats cluster:indices.docs.count` to get documents count of the whole cluster. The **nodes_stats indices.*** metrics are available for all of the cluster nodes, all other metrics are just for a local node only.

Except this three metrics sub groups script has *"service"* metrics but it's only used as `service ping` which shows if service is alive.

Provided templates rely on the described script operation and provide many useful items for monitoring Elasticsearch. More new items can be easily introduced without changes into the script, since these metric groups include even more useful metrics data than ESzabbix templates implements.

Authors
=======
* Denis Barishev (<denis.barishev@gmail.com>)
