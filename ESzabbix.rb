#!/usr/bin/env ruby

require 'elasticsearch'

class ElasticStats
  attr_reader :indices, :source, :item, :item_map

  def initialize(source, item)
    @indices = {
      docs:         ['count', 'deleted'],
      get:          ['missing_total', 'exists_total', 'current', 'time_in_millis', 'missing_time_in_millis', 'exists_time_in_millis', 'total'],
      search:       ['query_total', 'fetch_time_in_millis', 'fetch_total', 'fetch_time', 'query_current', 'fetch_current', 'query_time_in_millis'],
      indexing:     ['delete_time_in_millis', 'index_total', 'index_current', 'delete_total', 'index_time_in_millis', 'delete_current'],
      store:        ['size_in_bytes', 'throttle_time_in_millis'],
      filter_cache: ['filter_size_in_bytes', 'field_evictions'],
      fielddata:    ['field_size_in_bytes']
    }
    @item_map = {
      'filter_size_in_bytes' => 'memory_size_in_bytes',
      'field_size_in_bytes'  => 'memory_size_in_bytes',
      'field_evictions'      => 'evictions'
    }
    @source = source
    @item   = item
    if item.nil? or source.nil?
      zbx_fail("You must provide two script arguments source: cluster, service, node_id and item")
    end
  end

  # retrieve metric for cluster, node or service
  def metric
    index = indices.find {|o| o.last.include?(item)}
    index = index.nil? ? '' : index.first.to_s

    if source == 'cluster'
      # cluster items that will be aggregated
      if [:docs, :search, :indexing, :get, :store].include?(index.to_sym)
        stats = nodes_stats
        stats.inject(0) {|s, o| s + o['indices'][index][item_map[item] || item]}

      # otherwise it's supposed to be a cluster health item
      else
        stats = client.cluster.health
        case item
        when 'status'
          ['green', 'yellow', 'red'].find_index {|i| i == stats['status']}
        else
          stats[item] or zbx_fail("Unknown cluster health item: #{item}")
        end
      end
    elsif source == 'service'
      zbx_fail("Unknown service item: #{item}") if item != 'status'
      client.ping and 1 rescue 0
    else
      zbx_fail("Unknown indices item: #{item}") if index.empty? 
      stats = nodes_stats(source).first
      stats['indices'][index][item_map[item] || item]
    end
  end

  def nodes_stats(node_id=nil)
    client.nodes.stats({node_id: node_id, metric: 'indices', human: false})['nodes'].values
  end


  def client
    @client ||= begin
      c = Elasticsearch::Client.new
      c.transport.get_connection.connection.options.open_timeout = 2
      c.transport.get_connection.connection.options.timeout      = 3
      c
    end
  rescue
    zbx_fail("Couldn't connect to Elasticsearch")
  end

  # zabbix fail with unsupported item message
  def zbx_fail(msg=nil)
    puts "Error: #{msg}" if not msg.nil?
    puts "ZBX_NOTSUPPORTED"
    exit(2)
  end

end

elastic = ElasticStats.new(ARGV[0], ARGV[1])
puts elastic.metric
