#!/usr/bin/env ruby

# This script generates a report (in the log folder) on the coverage/levels of
# of service annotation.
#
# Usage: service_annotation_report [options]
#
#    -e, --environment=name           Specifies the environment to run this script under (test|development|production).
#                                     Default: production
#
#    -h, --help                       Show this help message.
#
# Dependencies:
# - All dependencies for the ServiceCatalogue application
# - Haml
# - Hashie

require 'rubygems'
require 'optparse'
require 'benchmark'
require 'ostruct'
require 'hashie'
require 'pp'

require File.join(File.dirname(__FILE__), "shared", "counter.rb")

NOT_APPLICABLE = "N/A".freeze

class ServiceAnnotationReporter
  
  attr_accessor :options, :stats, :errors, :resource_types, :annotation_levels
  
  def initialize(args)
    @options = {
      :environment => (ENV['RAILS_ENV'] || "production").dup,
    }
    
    args.options do |opts|
      opts.on("-e", "--environment=name", String,
              "Specifies the environment to run this script under (test|development|production).",
              "Default: production") { |v| @options[:environment] = v }
    
      opts.separator ""
    
      opts.on("-h", "--help", "Show this help message.") { puts opts; exit }
      
      opts.parse!
    end
    
    @resource_types = [ OpenStruct.new({ :key => :services, :name => "All Services" }), 
                        OpenStruct.new({ :key => :soap_services, :name => "SOAP Services" }), 
                        OpenStruct.new({ :key => :rest_services, :name => "REST Services" }),
                        OpenStruct.new({ :key => :soap_operations, :name => "SOAP Operations" }),
                        OpenStruct.new({ :key => :soap_inputs, :name => "SOAP Inputs" }),
                        OpenStruct.new({ :key => :soap_outputs, :name => "SOAP Outputs" }),
                        OpenStruct.new({ :key => :rest_methods, :name => "REST Methods" }),
                        OpenStruct.new({ :key => :rest_parameters, :name => "REST Parameters" }),
                        OpenStruct.new({ :key => :rest_representations, :name => "REST Representations" }) ].freeze
    
    @annotation_levels = [ OpenStruct.new({ :key => :a, :level => 1, :description => "Services that have a description" }),
                           OpenStruct.new({ :key => :b, :level => 2, :description => "Services that have a description AND a documentation URL" }),
                           OpenStruct.new({ :key => :c, :level => 3, :description => "Services that have a description AND all operations/methods have a description" }),
                           OpenStruct.new({ :key => :d, :level => 4, :description => "Services that have a description AND all operations/methods have a description AND all inputs/outputs have a description" }),
                           OpenStruct.new({ :key => :e, :level => 5, :description => "Services that have a description AND all operations/methods have a description AND all inputs/outputs have a description and an example" }) ].freeze
    
    # @stats is a special kind of hash that allow Javascript like
    # property accessors on the keys.
    @stats = Hashie::Mash.new
    
    @errors = [ ]
    
    # Start the Rails app
    
    ENV["RAILS_ENV"] = @options[:environment]
    Rails.env = ActiveSupport::StringInquirer.new(@options[:environment])
    
    require File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment')
    
    # Set up Haml
    gem 'haml'
    require 'haml'
    require 'haml/template'
    Haml::Template.options[:escape_html] = true
    @haml_engine = Haml::Engine.new(IO.read(File.join(File.dirname(__FILE__), "service_annotation_report", "template.haml")))
  end  
  
  def run
    current_time = Time.now.strftime('%Y%m%d-%H%M')
    
    calculate_stats
    
    puts "\n*****\nStoring raw stats in: 'log/service_annotation_stats_#{current_time}.json'\n*****\n"
    
    File.open(File.join(File.dirname(__FILE__), '..', '..', 'log', "service_annotation_stats_#{current_time}.json"), "w") { |f| 
      f.write @stats.to_json
    }
    
    puts "\n*****\nStoring report in: 'log/service_annotation_report_#{current_time}.html'\n*****\n"
    
    File.open(File.join(File.dirname(__FILE__), '..', '..', 'log', "service_annotation_report_#{current_time}.html"), "w") { |f| 
      f.write generate_html_content(current_time)
    }
  end
  
  # Calculates all the required stats for the report.
  #
  # Contains:
  #   - @stats.resources
  #     - @stats.resources.{resource_type}
  #       - @stats.resources.{resource_type}.id
  #       - @stats.resources.{resource_type}.name
  #       - @stats.resources.{resource_type}.url
  #       - @stats.resources.{resource_type}.has_description
  #       - @stats.resources.{resource_type}.has_tag
  #       - @stats.resources.{resource_type}.has_example
  #       - @stats.resources.services.service_type
  #       - @stats.resources.services.service_instance
  #       - @stats.resources.soap_services.has_documentation_url
  #       - @stats.resources.rest_services.has_documentation_url
  #       - @stats.resources.soap_services.soap_operations
  #       - @stats.resources.rest_services.rest_methods
  #       - @stats.resources.soap_operations.inputs
  #       - @stats.resources.soap_operations.outputs
  #       - @stats.resources.rest_methods.inputs
  #       - @stats.resources.rest_methods.outputs
  #   - @stats.summary
  #     - @stats.summary.resources
  #       - @stats.summary.resources.{resource_type}
  #         - @stats.summary.resources.{resource_type}.total
  #         - @stats.summary.resources.{resource_type}.has_descriptions
  #         - @stats.summary.resources.{resource_type}.has_tags
  #         - @stats.summary.resources.{resource_type}.has_examples
  #   - @stats.summary.levels
  #     - @stats.summary.levels.{level_key}
  #
  # NOTE: some statistics are not relevant for individual resource types since only certain annotations
  #       should be on certain resource types. See http://www.biocatalogue.org/wiki/doku.php?id=development:annotation.
  def calculate_stats
    @stats = Hashie::Mash.new
    
    @stats.resources = Hashie::Mash.new
    @stats.summary = Hashie::Mash.new
    @stats.summary.resources = Hashie::Mash.new
    @stats.summary.levels = Hashie::Mash.new
    
    # Initialise some of the collections
    
    @resource_types.each do |r|
      @stats.resources[r.key] = [ ]
      @stats.summary.resources[r.key] = Hashie::Mash.new
      @stats.summary.resources[r.key].total = 0
    end
    
    # Build the information about the resources
    
    Service.all.each do |service|
      unless service.archived?
        s = Hashie::Mash.new
        s.id = service.id
        s.name = ServiceCatalographer::Util.display_name(service)
        s.url = ServiceCatalographer::Api.uri_for_object(service)
        s.has_description = NOT_APPLICABLE
        s.has_tag = ServiceCatalographer::Util.field_or_annotation_has_value?(service, :tag)
        s.has_example = NOT_APPLICABLE
        
        service_instance = service.latest_version.service_versionified
        
        s.service_type = service_instance.service_type_name
        
        si = Hashie::Mash.new
        si.id = service_instance.id
        si.name = ServiceCatalographer::Util.display_name(service_instance)
        si.url = ServiceCatalographer::Api.uri_for_object(service_instance)
        si.has_tag = NOT_APPLICABLE
        si.has_example = NOT_APPLICABLE
        si.has_documentation_url = ServiceCatalographer::Util.field_or_annotation_has_value?(service_instance, :documentation_url)
        
        case service_instance
          when SoapService
            si = stats_hash_for_soap_service(si, service_instance)
            @stats.resources.soap_services << si
            @stats.summary.resources.soap_services.total += 1
          when RestService
            si = stats_hash_for_rest_service(si, service_instance)
            @stats.resources.rest_services << si
            @stats.summary.resources.rest_services.total += 1
        end
        
        s.service_instance = si
        
        @stats.resources.services << s
        @stats.summary.resources.services.total += 1
      end
    end
    
    # Now generate the summary stats
    
#    @stats.summary.resources.services.total = Service.count(:conditions => "archived_at IS NULL")
#    @stats.summary.resources.soap_services.total = SoapService.count(:conditions => "archived_at IS NULL")
#    @stats.summary.resources.soap_operations.total = SoapOperation.count(:conditions => "archived_at IS NULL")
#    @stats.summary.resources.soap_inputs.total = SoapInput.count(:conditions => "archived_at IS NULL")
#    @stats.summary.resources.soap_outputs.total = SoapOutput.count(:conditions => "archived_at IS NULL")
#    @stats.summary.resources.rest_services.total = RestService.count(:conditions => "archived_at IS NULL")
#    @stats.summary.resources.rest_methods.total = RestMethod.count(:conditions => "archived_at IS NULL")
#    @stats.summary.resources.rest_parameters.total = RestParameter.count(:conditions => "archived_at IS NULL")
#    @stats.summary.resources.rest_representations.total = RestRepresentation.count(:conditions => "archived_at IS NULL")
    
    @resource_types.each do |r|
      @stats.summary.resources[r.key].has_descriptions = calculate_summary_total_for(r.key, :has_description)
      @stats.summary.resources[r.key].has_tags = calculate_summary_total_for(r.key, :has_tag)
      @stats.summary.resources[r.key].has_examples = calculate_summary_total_for(r.key, :has_example)
    end
    
    @annotation_levels.each do |l|
      @stats.summary.levels[l.key] = calculate_summary_level_for(l.level)
    end
  end
  
  def generate_html_content(timestamp)
    @haml_engine.render Object.new, 
                        :timestamp => timestamp, 
                        :resource_types => @resource_types, 
                        :annotation_levels => @annotation_levels, 
                        :stats => @stats, 
                        :errors => @errors,
                        :helper => Helper.new
  end
  
  def stats_hash_for_soap_service(container, soap_service)
    container.has_description = (ServiceCatalographer::Util.field_or_annotation_has_value?(soap_service, :description) || !soap_service.description_from_soaplab.blank?)
    
    container.soap_operations = [ ]
    
    soap_service.soap_operations.each do |soap_operation|
      sop = Hashie::Mash.new
      sop.id = soap_operation.id
      sop.name = ServiceCatalographer::Util.display_name(soap_operation)
      sop.url = ServiceCatalographer::Api.uri_for_object(soap_operation)
      sop.has_description = ServiceCatalographer::Util.field_or_annotation_has_value?(soap_operation, :description)
      sop.has_tag = ServiceCatalographer::Util.field_or_annotation_has_value?(soap_operation, :tag)
      sop.has_example = NOT_APPLICABLE
      
      sop.inputs = [ ]
      sop.outputs = [ ]
      
      soap_operation.soap_inputs.each do |soap_input|
        sin = Hashie::Mash.new
        sin.id = soap_input.id
        sin.name = ServiceCatalographer::Util.display_name(soap_input)
        sin.url = ServiceCatalographer::Api.uri_for_object(soap_input)
        sin.has_description = ServiceCatalographer::Util.field_or_annotation_has_value?(soap_input, :description)
        sin.has_tag = ServiceCatalographer::Util.field_or_annotation_has_value?(soap_input, :tag)
        sin.has_example = ServiceCatalographer::Util.field_or_annotation_has_value?(soap_input, :example_data)
        
        sop.inputs << sin
        
        @stats.resources.soap_inputs << sin
        @stats.summary.resources.soap_inputs.total += 1
      end
      
      soap_operation.soap_outputs.each do |soap_output|
        sout = Hashie::Mash.new
        sout.id = soap_output.id
        sout.name = ServiceCatalographer::Util.display_name(soap_output)
        sout.url = ServiceCatalographer::Api.uri_for_object(soap_output)
        sout.has_description = ServiceCatalographer::Util.field_or_annotation_has_value?(soap_output, :description)
        sout.has_tag = ServiceCatalographer::Util.field_or_annotation_has_value?(soap_output, :tag)
        sout.has_example = ServiceCatalographer::Util.field_or_annotation_has_value?(soap_output, :example_data)
        
        sop.outputs << sout
        
        @stats.resources.soap_outputs << sout
        @stats.summary.resources.soap_outputs.total += 1
      end
      
      container.soap_operations << sop
      
      @stats.resources.soap_operations << sop
      @stats.summary.resources.soap_operations.total += 1
    end
    
    return container
  end
  
  def stats_hash_for_rest_service(container, rest_service)
    container.has_description = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_service, :description)
    
    container.rest_methods = [ ]
    
    rest_service.rest_methods.each do |rest_method|
      rm = Hashie::Mash.new
      rm.id = rest_method.id
      rm.name = ServiceCatalographer::Util.display_name(rest_method)
      rm.url = ServiceCatalographer::Api.uri_for_object(rest_method)
      rm.has_description = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_method, :description)
      rm.has_tag = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_method, :tag)
      rm.has_example = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_method, :example_endpoint)
      
      rm.inputs = [ ]
      rm.outputs = [ ]
      
      rest_method.request_parameters.each do |rest_parameter|
        rinp = Hashie::Mash.new
        rinp.id = rest_parameter.id
        rinp.name = ServiceCatalographer::Util.display_name(rest_parameter)
        rinp.url = ServiceCatalographer::Api.uri_for_object(rest_parameter)
        rinp.has_description = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_parameter, :description)
        rinp.has_tag = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_parameter, :tag)
        rinp.has_example = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_parameter, :example_data)
        
        rm.inputs << rinp
        
        @stats.resources.rest_parameters << rinp
        @stats.summary.resources.rest_parameters.total += 1
      end
      
      rest_method.request_representations.each do |rest_representation|
        rinrep = Hashie::Mash.new
        rinrep.id = rest_representation.id
        rinrep.name = ServiceCatalographer::Util.display_name(rest_representation)
        rinrep.url = ServiceCatalographer::Api.uri_for_object(rest_representation)
        rinrep.has_description = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_representation, :description)
        rinrep.has_tag = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_representation, :tag)
        rinrep.has_example = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_representation, :example_data)
        
        rm.inputs << rinrep
        
        @stats.resources.rest_representations << rinrep
        @stats.summary.resources.rest_representations.total += 1
      end
      
      rest_method.response_parameters.each do |rest_parameter|
        routp = Hashie::Mash.new
        routp.id = rest_parameter.id
        routp.name = ServiceCatalographer::Util.display_name(rest_parameter)
        routp.url = ServiceCatalographer::Api.uri_for_object(rest_parameter)
        routp.has_description = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_parameter, :description)
        routp.has_tag = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_parameter, :tag)
        routp.has_example = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_parameter, :example_data)
        
        rm.outputs << routp
        
        @stats.resources.rest_parameters << routp
        @stats.summary.resources.rest_parameters.total += 1
      end
      
      rest_method.response_representations.each do |rest_representation|
        routrep = Hashie::Mash.new
        routrep.id = rest_representation.id
        routrep.name = ServiceCatalographer::Util.display_name(rest_representation)
        routrep.url = ServiceCatalographer::Api.uri_for_object(rest_representation)
        routrep.has_description = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_representation, :description)
        routrep.has_tag = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_representation, :tag)
        routrep.has_example = ServiceCatalographer::Util.field_or_annotation_has_value?(rest_representation, :example_data)
        
        rm.outputs << routrep
        
        @stats.resources.rest_representations << routrep
        @stats.summary.resources.rest_representations.total += 1
      end
      
      container.rest_methods << rm
      
      @stats.resources.rest_methods << rm
      @stats.summary.resources.rest_methods.total += 1
    end
    
    return container
  end
  
  def calculate_summary_total_for(resource_type_key, field)
    value = "Not calculated"
    
    # Check the first one of these resources to see if the field is applicable for this resource
    
    unless @stats.resources[resource_type_key].empty? or @stats.resources[resource_type_key].first[field].nil? 
      if @stats.resources[resource_type_key].first[field] == NOT_APPLICABLE
        value = NOT_APPLICABLE
      else
        counter = Counter.new
      
        @stats.resources[resource_type_key].each do |r|
          if r[field] == true
            counter.increment
          end
        end
        
        value = counter.count
      end
    end
    
    return value
  end
  
  def calculate_summary_level_for(level)
    counter = Counter.new
    
    case level
      when 1
        @stats.resources.services.each do |s|
          if s.service_instance.has_description == true
            counter.increment
          end
        end
      when 2
        @stats.resources.services.each do |s|
          if (s.service_instance.has_description == true) && (s.service_instance.has_documentation_url == true)
            counter.increment
          end
        end
      when 3
        @stats.resources.services.each do |s|
          if s.service_instance.has_description == true
            collection = s.service_instance.soap_operations
            collection ||= s.service_instance.rest_methods
            
            has = true
            
            collection.each do |c|
              has = has && (c.has_description == true)
            end
            
            counter.increment if has
          end
        end
      when 4
        @stats.resources.services.each do |s|
          if s.service_instance.has_description == true
            collection = s.service_instance.soap_operations
            collection ||= s.service_instance.rest_methods
            
            has = true
            
            collection.each do |c|
              has = has && (c.has_description == true)
              
              if has
                c.inputs.each do |i|
                  has = has && (i.has_description == true)
                end
                
                c.outputs.each do |o|
                  has = has && (o.has_description == true)
                end
              end
            end
            
            counter.increment if has
          end
        end
      when 5
        @stats.resources.services.each do |s|
          if s.service_instance.has_description == true
            collection = s.service_instance.soap_operations
            collection ||= s.service_instance.rest_methods
            
            has = true
            
            collection.each do |c|
              has = has && (c.has_description == true)
              
              if has
                c.inputs.each do |i|
                  has = has && (i.has_description == true) && (i.has_example == true)
                end
                
                c.outputs.each do |o|
                  has = has && (o.has_description == true) && (o.has_example == true)
                end
              end
            end
            
            counter.increment if has
          end
        end
    end
    
    return counter.count
  end
  
end

class Helper
  def format_value(value, total=nil)
    case value
      when Numeric
        if total and total.is_a? Numeric
          return "#{number_with_delimiter(value)}&nbsp;&nbsp;[<b>#{value.percent_of(total).round(1)}%</b>]"
        else
          return number_with_delimiter(value)
        end
    end
    
    return value.try(:to_s)
  end
  
  def total_service_instances(stats)
    return stats.summary.resources.soap_services.total + stats.summary.resources.rest_services.total
  end
  
  def number_with_delimiter(number, options = {})
    options.symbolize_keys!
    
    begin
      Float(number)
    rescue ArgumentError, TypeError
      if options[:raise]
        raise InvalidNumberError, number
      else
        return number
      end
    end
    
    defaults = I18n.translate(:'number.format', :locale => options[:locale], :default => {})
    options = options.reverse_merge(defaults)
    
    parts = number.to_s.split('.')
    parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{options[:delimiter]}")
    parts.join(options[:separator])
    
  end
end

puts Benchmark.measure {
  ServiceAnnotationReporter.new(ARGV.clone).run
}
