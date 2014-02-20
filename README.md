Elasticsearch-zabbix
====================

Elasticsearch template and script for zabbix 2.0

This project is a fork of Elasticsearch template from zabbix-grab-bag

https://github.com/untergeek/zabbix-grab-bag

These are made available by me under an Apache 2.0 license.

http://www.apache.org/licenses/LICENSE-2.0.html

Introduction
============

Scripts were reworked to ruby version. **ESzabbix.rb** requires *elasticsearch* gem, script works much faster than it's python version. This probably happens because of buggy *pyes* module, the connection to elasticsearch happens obscenely longat list with pyes 0.19.0. The next version of pyes doesn't work with Python 2.6. So the script was dismissed in favour of ruby version.

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

The node name is expected as a host-level macro {$NODENAME}

There are triggers assigned for the cluster state:

0 = Green (OK)

1 = Yellow (Average, depends on "red")

2 = Red (High)


You will likely want to assign a value mapping for the ElasticSearch Cluster Status item.

In any event, the current list of included items is:

* ES Cluster (11 Items)
    - Cluster-wide records indexed per second
	- Cluster-wide storage size
	- ElasticSearch Cluster Status
	- Number of active primary shards
	- Number of active shards
	- Number of data nodes
	- Number of initializing shards
	- Number of nodes
	- Number of relocating shards
	- Number of unassigned shards
	- Total number of records
* ES Cache (2 Items)
	- Node Field Cache Size
	- Node Filter Cache Size
* ES Node (2 Items)
	- Node Storage Size
	- Records indexed per second
* ES Service (1 Item)
	- Elasticsearch service status
