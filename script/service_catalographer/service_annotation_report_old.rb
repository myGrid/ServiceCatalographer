#!/usr/bin/env ruby

# Reports on the statistics of service annotations.
#
# Currently this just tells you: 
# A. How many SOAP Services that have a description.
# B. How many SOAP Services that have a description AND a documentation URL.
# C. How many SOAP Services that have a description AND all operations have a description.
# D. How many SOAP Services that have a description AND all operations have a description and ALL inputs/outputs have a description.
# E. How many SOAP Services that have a description AND all operations have a description and ALL inputs/outputs have a description AND example data.

env = "production"

unless ARGV[0].nil? or ARGV[0] == ''
  env = ARGV[0]
end

Rails.env = ActiveSupport::StringInquirer.new(env)

# Load up the Rails app
require File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment')

soap_services = SoapService.all

stats = { }
stats["soap_services_count"] = 0
stats["soap_operations_count"] = 0
stats["soap_inputs_count"] = 0
stats["soap_outputs_count"] = 0
stats["soap_services_A"] = 0
stats["soap_services_B"] = 0
stats["soap_services_C"] = 0
stats["soap_services_D"] = 0
stats["soap_services_E"] = 0

stats["soap_services_E_service_ids"] = [ ] 


def field_or_annotation_has_value?(obj, field, annotation_attribute=field.to_s)
  return (!obj.send(field).blank? || !obj.annotations_with_attribute(annotation_attribute, true).blank?)
end


soap_services.each do |soap_service|
  
  if soap_service.service.archived?
    
    puts "\nService ID: #{soap_service.service.id} is archived so ignoring."
    
  else
    
    stats["soap_services_count"] += 1
  
    has_description = true
    has_doc_url = true
    all_ops_have_descriptions = true
    all_inputs_have_descriptions = true
    all_inputs_have_descriptions_and_data = true
    all_outputs_have_descriptions = true
    all_outputs_have_descriptions_and_data = true
    
    has_description = has_description && (field_or_annotation_has_value?(soap_service, :description) || !soap_service.description_from_soaplab.blank?)
    
    has_doc_url = has_doc_url && field_or_annotation_has_value?(soap_service, :documentation_url)
    
    soap_service.soap_operations.each do |soap_operation|
      
      if soap_operation.archived?
      
        puts "\nSOAP Operation ID: #{soap_operation.id} is archived so ignoring."
      
      else
      
        stats["soap_operations_count"] += 1
      
        all_ops_have_descriptions = all_ops_have_descriptions && field_or_annotation_has_value?(soap_operation, :description)
        
        soap_operation.soap_inputs.each do |soap_input|
          
          if soap_input.archived?
            
            puts "\nSOAP Input ID: #{soap_input.id} is archived so ignoring."
            
          else
            
            stats["soap_inputs_count"] += 1
            
            all_inputs_have_descriptions = all_inputs_have_descriptions && field_or_annotation_has_value?(soap_input, :description)
            all_inputs_have_descriptions_and_data = all_inputs_have_descriptions_and_data && 
                                                    field_or_annotation_has_value?(soap_input, :description) &&
                                                    !soap_input.annotations_with_attribute("example_data").blank?
            
          end
          
        end
        
        soap_operation.soap_outputs.each do |soap_output|
          
          if soap_output.archived?
            
            puts "\nSOAP Output ID: #{soap_output.id} is archived so ignoring."
            
          else
            
            stats["soap_outputs_count"] += 1
            
            all_outputs_have_descriptions = all_outputs_have_descriptions && field_or_annotation_has_value?(soap_output, :description)
            all_outputs_have_descriptions_and_data = all_outputs_have_descriptions_and_data && 
                                                    field_or_annotation_has_value?(soap_output, :description) &&
                                                    !soap_output.annotations_with_attribute("example_data").blank?
          
          end
        
        end
      
      end
      
    end
    
    puts ""
    puts "> SOAP Service ID: #{soap_service.id}, name: #{soap_service.name}:"
    puts "\t Has description? #{has_description}"
    puts "\t Has documentation URL? #{has_doc_url}"
    puts "\t No. of SOAP operations: #{soap_service.soap_operations.count}"
    puts "\t ALL operations have descriptions? #{all_ops_have_descriptions}"
    puts "\t ALL inputs have descriptions? #{all_inputs_have_descriptions}"
    puts "\t ALL inputs have descriptions AND example data? #{all_inputs_have_descriptions_and_data}"
    puts "\t ALL outputs have descriptions? #{all_outputs_have_descriptions}"
    puts "\t ALL outputs have descriptions AND example data? #{all_outputs_have_descriptions_and_data}"
    puts ""
    
    stats["soap_services_A"] += 1 if has_description
    stats["soap_services_B"] += 1 if has_description && has_doc_url
    stats["soap_services_C"] += 1 if has_description && all_ops_have_descriptions
    stats["soap_services_D"] += 1 if has_description && all_ops_have_descriptions && all_inputs_have_descriptions && all_outputs_have_descriptions
    
    if has_description && all_ops_have_descriptions && all_inputs_have_descriptions_and_data && all_outputs_have_descriptions_and_data
      stats["soap_services_E"] += 1
      stats["soap_services_E_service_ids"] << soap_service.service.id
    end

  end

end


def report_stats(stats)
  puts ""
  puts "SUMMARY:"
  puts "========"
  puts ""
  
  puts "NOTE: all archived services, operations, inputs and outputs are ignored."
  puts ""
  
  puts "Total SOAP Services: #{stats["soap_services_count"]}"
  puts "Total SOAP Operations: #{stats["soap_operations_count"]}"
  puts "Total SOAP Inputs: #{stats["soap_inputs_count"]}"
  puts "Total SOAP Outputs #{stats["soap_outputs_count"]}"
  puts ""
  
  puts "A. How many SOAP Services have a description? #{stats["soap_services_A"]}"
  puts "B. How many SOAP Services have a description AND a documentation URL? #{stats["soap_services_B"]}"
  puts "C. How many SOAP Services have a description AND all operations have a description? #{stats["soap_services_C"]}"
  puts "D. How many SOAP Services have a description AND all operations have a description and ALL inputs/outputs have a description? #{stats["soap_services_D"]}"
  puts "E. How many SOAP Services have a description AND all operations have a description and ALL inputs/outputs have a description AND example data? #{stats["soap_services_E"]}"
  
  puts "Service IDs for E - #{stats["soap_services_E_service_ids"].to_sentence}"
end


report_stats(stats)


