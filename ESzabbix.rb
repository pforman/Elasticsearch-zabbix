#!/usr/bin/env ruby

require 'elasticsearch'
require 'json'

class ESStats
  attr_reader :es_read_timeout, :cache_timeout, :metrics, :cache_file

  def initialize
    @es_read_timeout = 10
    @metrics       = ['jvm', 'os' ,'process']
    @cache_file    = '/tmp/eszabbix_stats.cache'
    @cache_timeout = 60
    @node_id       = nil
  end

  # Read es statistics, cache opearation.
  def stats
    @stats ||= begin
      mtime = File.mtime(cache_file) rescue (Time.now - cache_timeout)

      # load statistics from elasticsearch
      if Time.now - mtime > cache_timeout
        hash  = {node_id: '_local'}
        metrics.inject(hash) {|h, v| h[v.to_sym] = true; h}
        node_info = client.nodes.info(hash)
        node_id   = node_info['nodes'].keys.first

        # read indices stats for all cluster nodes
        stats = client.nodes.stats metric: 'indices'
        stats['nodes'][node_id].merge!(node_info['nodes'][node_id])

        # cache results
        File.open(cache_file, 'w') {|f| f.write(JSON.pretty_generate(stats))}
        stats
      else
        # from cache
        JSON.parse(IO.read(cache_file))
      end
    end
  end

  def node_id
    @node_id ||= begin
      # node_id becomes available after stats has been read
      # local node is the only one which has extended metrics
      idx = stats['nodes'].find_index do |id, hash|
        hash.keys.any? {|k| metrics.include? k}
      end
      stats['nodes'].keys[idx]
    end
  end

  # return client with preconfigured timeout
  def client
    @client ||= begin
      c = Elasticsearch::Client.new
      c.transport.get_connection.connection.options.open_timeout = es_read_timeout
      c.transport.get_connection.connection.options.timeout      = es_read_timeout
      c
    end
  end
end

class ESZabbix
  attr_reader :es, :path, :item

  def initialize
    @es = ESStats.new
    @mode = nil
    @modes_supported = :cluster, :service
    @service_items = ['ping']
    @cluster_items = ['health']
  end

  def metric(item)
    parse_item(item)
    case mode
    when :service
      service_value
    when :cluster
      cluster_value
    else
      # get value directly from node statistics
      direct_value_from(es.stats['nodes'][es.node_id])
    end
  rescue Timeout::Error
    zbx_fail "Couldn't connect to ElasticSearch opearation timed out"
  rescue Exception => e
    zbx_fail e.message + "\n" + e.backtrace.join("\n")
  end

  private

  attr_reader :mode

  # retrieve cluster metric value
  def cluster_value
    case path
    when 'health'
      stats = es.client.cluster.health
      # 0, 1, 2 for green, yellow, red respectively
      ['green', 'yellow', 'red'].find_index {|i| i == stats['status']}
    else
      unless path.start_with?('indices')
        zbx_fail "Cluster aggregation is only available for indices metrics"
      end
      es.stats['nodes'].inject(0) do |value, pair|
        node_stats = pair.last
        value = value + direct_value_from(node_stats)
      end
    end
  rescue Timeout::Error
    # In case of timeout health is reported as GREEN! The actual cluster health
    # must be aggregated in zabbix to avoid useless triggering for each node.
    path == 'health' ? 0 : raise
  end

  # retrieve cluster metric value
  def service_value
    case path
    when 'ping'
      es.client.ping ? 1 : 0
    else
      zbx_fail("Unknown service item #{path}")
    end
  rescue Timeout::Error
    0
  end

  def direct_value_from(hash)
    value = path.split('.').inject(hash) {|h, i| h[i]}
    value or zbx_fail "Value for item #{path} is empty"
  end

  # parse item like "(cluster:)indices.docs.count"
  def parse_item(item)
    @item = item
    zbx_fail "You must provide zabbix statistics path like: (cluster:)indices.docs.count" if item.nil?
    parsed = item.split(/(\w+):/)
    case parsed[1]
    when nil
      @path = parsed[0].to_s
    when 'cluster', 'service'
      @mode = parsed[1].to_sym
      @path = parsed[2].to_s
    else
      zbx_fail "Unknown opearation mode #{parsed[1]}"
    end
  end

  # zabbix fail with unsupported item message
  def zbx_fail(msg=nil)
    puts "Error: #{msg}" if not msg.nil?
    puts "ZBX_NOTSUPPORTED"
    exit(2)
  end
end

stats = ESZabbix.new
puts stats.metric(ARGV[0])
