#!/usr/bin/env script/runner
require 'optparse'
require 'rgl/dot'
DOT=RGL::DOT
$options = {:output_method => :objects_to_yaml, :model => :sample_with_assets}
$objects = []
$already_pulled = {}

class Hidden < Array
end

# Model descriptions can be specified for subclass.
# use :skip_super to not include superclass association
Models = {
  :sample_with_assets =>  {
    Sample => [:assets, :study_samples],
    StudySample => [:study],
    Asset => [:requests, :children, :parents],
    Well => [:container_association],
    ContainerAssociation => [:container, :content] ,
    Request => [:submission, :asset,:item,  :target_asset, :request_metadata, :user],
    Submission => [:asset_group]
  },
  :submission => {
    Submission => [:study, :project, lambda { |s|  s.requests.group_by(&:request_type_id).values },
      :requests_by_type, :asset_group],
    Request => [:asset, :target_asset],
    Asset => lambda { |s|  s.requests.group_by(&:request_type_id).values },
    AssetGroup => [:assets]
  },
  :bare => {}
}

optparse = OptionParser.new do |opts|
  opts.on('-s', '--sample id_or_name', 'sample to pull') do |sample|
    $objects<< [Sample, sample]
  end

  opts.on('--study id_or_name', 'study to pull') do |study|
    $objects<< [Study, study]
  end

  opts.on('--submission id_or_name', 'submission to pull') do |submission|
    $objects << [Submission, submission]
  end

  opts.on('-rt','--request_type', 'request types') do |request_types|
    $objects<< [RequestType, request_types]
  end

  opts.on '-m' '--model', 'model of what needs to be pull' do |model_name|
    $options[:model]=model_name
  end
  opts.on('-r', '--ruby', 'Generate a ruby script') do 
    $options[:output_method] = :objects_to_script
  end

  opts.on('-g', '--graph type', 'Generate a dot graph') do |type|
    $options[:output_method] =:objects_to_graph
    set_graph_filter_option(type)
  end
  opts.on('-d', '--digraph type', 'Generate a dot graph') do |type|
    $options[:output_method] =:objects_to_digraph
    set_graph_filter_option(type)
  end
end

def set_graph_filter_option(type)
    $options[:block] = case type
                       when "full"
                         Proc.new do |object, parent|
                           { parent => object}
                         end
                       when "3max"
                         Proc.new do |object, parent, index, max_index|
                           if index == 2 and max_index > 2
                             # things been removed
                             Cut.new({ parent => [object, "#{[max_index-3, 1].max} x #{object.class.name}"]})
                           else
                             { parent => object} if [0,1,max_index].include?(index)
                           end
                         end
                       when "3center"
                         Proc.new do |object, parent, index, max_index|
                           # cut everything but one
                           kept_index = [1, max_index || 0].min
                           case index || kept_index
                           when kept_index
                               { parent => object}
                           when 0,max_index
                               # things been removed
                               #Cut.new({ parent => [object, object.class.name]})
                               Cut.new({ parent => [object, node_name(object)] })
                           when 2
                               #Cut.new({ parent => [object, "..."]})
                               Cut.new({ parent => [object, "#{[max_index-3, 1].min} x #{object.class.name}"]})
                           else 
                               Cut.new({ parent => Hidden.new([object, "#{[max_index-3, 1].min} x #{object.class.name}"])})
                           end
                         end
                       end
end
def load_objects(objects)
  loaded = []
  objects.each do |model, name|
    name.split(",").each do |name|
      if name =~ /\A\d+\Z/
        #name is an id
        object =  model.find_by_id(name)
      elsif name =~ /\A:(first|last)\Z/
        object = model.find(name)
      else
        object = model.find_by_name(name)
      end

      raise RuntimeError, "can't find #{model} '#{name}'" unless object
      loaded << object
    end
  end
  return loaded
end

def object_to_hash(object)
  att =object.attributes.reject { |k,v| [ :created_at, :updated_at ].include?(k.to_sym) }
  att.each do |k,v|
    if k =~ /name|login|email|decription|abstract|title/i and v.is_a?(String) and (k !~ /class_?name/)
      att[k] = "#{object.class.name}_#{object.id}_#{k}"
    end
  end
  att.reject { |k,v| !v }
end
def objects_to_script(objects)
  objects.map do |object|
    att = object_to_hash(object)
%Q{
#{object.class.name}.new(#{att.inspect}) { |r| r.id = #{object.id} }.save_without_validation
}
  end
end

def node_name(object)
  "#{object.class}##{object.id}"
end

def objects_to_graph(edges)
  edges  = edges.map(&:to_a).map(&:first)
  DOT::Graph.new("rankdir" => "LR").tap do |graph|
    node_map =  {}

    #create the node first
    edges.each do |parent, object|
      next unless object
      hidden = false
      if object.is_a?(Array)
        next if object.is_a?(Hidden)
        node = DOT::Node.new("label" => object[1], "name" => node_name(object[0]), "color" => "red" )
      else
        node = DOT::Node.new("name" => node_name(object), "style"=>"filled")
      end
      node_map[object] = node
      graph << node
    end
    edge_map= {}
    edges.each do |parent, object|
      next if edge_map[[object, parent]]
      next unless parent and object
      if object.is_a?(Hidden)
      debugger  if node_map[object.first]
      next if not node_map[object.first]
      object = object.first
      end
      edge = DOT::Edge.new
      edge.from = node_map[parent].name
      edge.to = node_map[object].name
      graph << edge
      edge_map[[parent, object]] = true
    end
  end
end
def objects_to_digraph(edges)
  edges  = edges.map(&:to_a).map(&:first)
  DOT::Digraph.new("rankdir" => "LR").tap do |graph|
    node_map =  {}

    #create the node first
    edges.each do |parent, object|
      next unless object
      next if object.is_a?(Hidden)
      if object.is_a?(Array)
        node = DOT::Node.new("label" => object[1], "name" => node_name(object[0]))
      else
        node = DOT::Node.new("name" => node_name(object), "style"=>"filled")
      end
      node_map[object] = node
      graph << node
    end
    edges.each do |parent, object|
      next if object.is_a?(Hidden)
      next unless parent and object
      edge = DOT::DirectedEdge.new
      edge.from = node_map[parent].name
      edge.to = node_map[object].name
      graph << edge
    end
  end
end

def objects_to_yaml(objects)
  objects.map do |object|
    att = object_to_hash(object)
    {:class => object.class.name, :id => object.id, :attributes => att}
  end.to_yaml
end

def find_model(model_name)
    model = Models[model_name.to_sym]
    raise "can't find model #{model_name}. Available models are #{Models.keys.inspect}" unless model
    model
end

ARGV.shift  # to remove the -- needed using script/runner
optparse.parse!
#puts $options.to_yaml
#puts $objects.to_yaml

Submission
class Submission
  def requests_by_type
    requests.group_by(&:request_type_id).values
  end
end


puts send($options[:output_method],
          load_objects($objects).walk_objects(find_model($options[:model]), &($options[:block])))
