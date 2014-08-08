# ServiceCatalographer: lib/service_catalographer/bljson.rb
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# Module to abstract out any specific processing for the custom ServiceCatalographer's "lean" JSON REST API

module ServiceCatalographer
  module Api
    module Bljson
      
      # 'results' should be a Hash with an "id" + anything that can be deemed a display_name. 
      def self.index(resource_type, results)
        output = { }
        
        output[resource_type.pluralize] = [ ]
        
        results.each do |item|
          item_json = { 
            :resource => ServiceCatalographer::Api.uri_for_path("/#{resource_type}/#{item["id"]}"),
            :name => ServiceCatalographer::Util.display_name(item)
          }
          
          if item["archived_at"] 
            item_json[:archived] = true 
          end
          
          output[resource_type.pluralize] << item_json
        end
        
        return output
      end
      
    end
  end
end