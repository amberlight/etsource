namespace :import do
  # Returns a hash where each key is the name of the sector, and the value is
  # an array containing all the nodes in that sector.
  def nodes_by_sector
    nodes = YAML.load_file(ETSource.root.join('topology/export.graph'))
    nodes = nodes.with_indifferent_access

    Dir.glob('datasets/nl/graph/**.yml').each do |file|
      YAML.load_file(file).each do |key, properties|
        nodes[key].merge!(properties) if nodes[key]
      end
    end

    nodes.group_by { |key, data| data['sector'] || 'nosector' }
  end

  # Given a node key and it's data, determines which subclass of Node should
  # be used.
  def node_subclass(key, data)
    return ETSource::FinalDemandNode if key.to_s.match(/final_demand/)
    return ETSource::DemandNode      if key.to_s.match(/demand/)

    out_slots, in_slots = data['slots'].partition { |s| s.match(/^\(/) }
    in_slots.map!  { |slot| match = slot.match(/\((.*)\)/) ; match[1] }
    out_slots.map! { |slot| match = slot.match(/\((.*)\)/) ; match[1] }

    if ((in_slots - ['loss']) - (out_slots - ['loss'])).any?
      # A node is a converter if it outputs energy in a different carrier than
      # it received; the exception being loss which we ignore.
      ETSource::Converter
    else
      ETSource::Node
    end
  end

  # Queries for final demand nodes.
  FD_QUERIES = {
    households_final_demand_coal:
      "EB(residential, coal_and_peat)",
    households_final_demand_crude_oil:
      "EB(residential, oil_products)",
    households_final_demand_network_gas:
      "EB(residential, natural_gas)",
    households_final_demand_solar_thermal:
      "EB(residential, 'Geothermal Solar, etc.')",
    households_final_demand_wood_pellets:
      "EB(residential, biofuels_and_waste)",
    households_final_demand_electricity:
      "EB(residential, electricity)",
    households_final_demand_steam_hot_water:
      "EB(residential, heat)"
  }.freeze

  # --------------------------------------------------------------------------

  # Loads ETSource.
  task :setup do
    $LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/..'))

    require 'fileutils'
    require 'etsource'
    require 'active_support/core_ext/hash/indifferent_access'
  end # task :setup

  # Sets the "query" attribute on final demand nodes.
  task :final_demand_queries do
    print 'Setting final demand queries... '
    nodes = ETSource::Collection.new(ETSource::Node.all)

    FD_QUERIES.each do |key, query|
      nodes.find(key).tap { |n| n.query = query; n.save! }
    end

    puts "done! (#{ FD_QUERIES.length } nodes)"
  end # task :final_demand_queries

  desc <<-DESC
    Import nodes from the old format to ActiveDocument.

    Reads the legacy export.graph file and the "nl" dataset, and creates
    new-style ActiveDocument files for each node.

    This starts by *deleting* everything in data/nodes on the assumption that
    there are no hand-made changes.
  DESC
  task nodes: :setup do
    # Wipe out *everything* in the nodes directory; rather than simply
    # overwriting existing files, since some may have new naming conventions
    # since the previous import.
    FileUtils.rm_rf(ETSource::Node.directory)

    nodes_by_sector.each do |sector, nodes|
      print "Processing nodes for #{ sector } sector... "

      nodes.each do |key, data|
        raise "Node #{ key.inspect } has no slots?!" unless data['slots']

        klass = node_subclass(key, data)

        # Split the original slots array into two, containing the outgoing and
        # incoming slots respectively. This is done by recognising that
        # outgoing slots begin with the carrier key in (brackets).
        out_slots, in_slots = data['slots'].partition { |s| s.match(/^\(/) }

        data[:in_slots]  = in_slots.map  { |slot| slot.match(/\((.*)\)/)[1] }
        data[:out_slots] = out_slots.map { |slot| slot.match(/\((.*)\)/)[1] }

        data.delete('links')
        data.delete('slots')

        data[:path] = "#{ sector }/#{ key }"

        klass.new(data).save!
      end

      puts "done! (#{ nodes.length } nodes)"
    end # nodes_by_sector.each

    Rake::Task['import:final_demand_queries'].invoke
  end # task :nodes

  desc <<-DESC
    Import edges from the old format to ActiveDocument.

    This starts by *deleting* everything in data/edges on the assumption that
    there are no hand-made changes.
  DESC
  task edges: :setup do
    include ETSource

    # Wipe out *everything* in the edges directory; rather than simply
    # overwriting existing files, since some may have new naming conventions
    # since the previous import.
    FileUtils.rm_rf(Edge.directory)

    link_re = /
      (?<consumer>[\w_]+)-       # Child node key
      \([^)]+\)\s                # Carrier key (ignored)
      (?<reversed><)?            # Arrow indicating a reversed link?
      --\s(?<type>\w)\s-->?\s    # Link type and arrow
      \((?<carrier>[^)]+)\)-     # Carrier key
      (?<supplier>[\w_]+)        # Parent node key
    /xi

    nodes_by_sector.each do |sector, nodes|
      print "Processing edges for #{ sector } sector... "

      sector_dir = Edge.directory.join(sector)
      edges      = nodes.map { |key, node| node['links'] }.flatten.compact

      edges.each do |link|
        unless data = link_re.match(link)
          raise "Non-matching link: #{ link.inspect } for #{ node_key.inspect }"
        end

        type = case data[:type]
          when 's' then :share
          when 'f' then :flexible
          when 'c' then :constant
          when 'd' then :dependent
          when 'i' then :inverse_flexible
        end

        # We currently have to construct the full path manually since Edge
        # does not (yet) account for the sector.
        key   = Edge.key(data[:consumer], data[:supplier], data[:carrier])
        path  = sector_dir.join(key.to_s)

        props = { path: path, type: type, reversed: ! data[:reversed].nil? }

        Edge.new(props).save!
      end

      puts "done! (#{ edges.length } edges)"
    end # nodes_by_sector.each
  end # task :edges

  task all: ['import:nodes', 'import:edges'] do
  end # task :all
end # namespace :import

desc 'Import edges and nodes from the old format to ActiveDocument'
task import: ['import:all']