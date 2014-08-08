# ServiceCatalographer: app/models/rest_representation.rb
#
# Copyright (c) 2009-2010, University of Manchester, The European Bioinformatics
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

class RestRepresentation < ActiveRecord::Base
  if ENABLE_CACHE_MONEY
    is_cached :repository => $cache
    index [ :submitter_type, :submitter_id ]
  end
  
  if ENABLE_TRASHING
    acts_as_trashable
  end
  
  acts_as_annotatable :name_field => :content_type

  acts_as_archived

  validates_presence_of :content_type
  
  has_submitter
  
  validates_existence_of :submitter # User must exist in the db beforehand.

  if ENABLE_SEARCH
    searchable do
      text :content_type, :description, :submitter_name
    end
  end

  if USE_EVENT_LOG
    acts_as_activity_logged(:models => { :culprit => { :model => :submitter } })
  end


  def display_name 
    return self.content_type
  end

  # ========================================
  
  # get all the RestMethodRepresentations that use this RestRepresentation
  def rest_method_representations
    RestMethodRepresentation.find_all_by_rest_representation_id(self.id)
  end


  # For the given rest_method object, find duplicate entry based on 'representation' and http_cycle
  # When http_cycle == "request", search the method's request representations for a dup.
  # When http_cycle == "response", search the method's response representations for a dup.
  # Otherwise search both request and response representations for a dup.
  def self.check_duplicate(rest_method, representation, http_cycle="")
    case http_cycle
      when "request"
        rep = rest_method.request_representations.find_by_content_type(representation)
      when "response"
        rep = rest_method.response_representations.find_by_content_type(representation)
      else
        rep = rest_method.request_representations.find_by_content_type(representation)
        rep = rest_method.response_representations.find_by_content_type(representation) unless rep
    end
    
    return rep # RestRepresentation || nil
  end

  # Check that a given representation exists for the given rest_service object
  def self.check_exists_for_rest_service(rest_service, representation)
    rep = nil
    
    rest_service.rest_resources.each do |resource|
      resource.rest_methods.each { |method| 
        rep = RestRepresentation.check_duplicate(method, representation)
        break if rep
      }
      break if rep
    end
    
    return rep # RestRepresentation || nil
  end

  def associated_service_id
    @associated_service_id ||= ServiceCatalographer::Mapper.map_compound_id_to_associated_model_object_id(ServiceCatalographer::Mapper.compound_id_for(self.class.name, self.id), "Service")
  end
  
  def associated_service
    @associated_service ||= Service.find_by_id(associated_service_id)
  end

  def associated_rest_method_id
    @associated_rest_method_id ||= ServiceCatalographer::Mapper.map_compound_id_to_associated_model_object_id(ServiceCatalographer::Mapper.compound_id_for(self.class.name, self.id), "RestMethod")
  end
  
  def associated_rest_method
    @associated_rest_method ||= RestMethod.find_by_id(associated_rest_method_id)
  end

  def to_json
    generate_json_and_make_inline(false)
  end 
  
  def to_inline_json
    generate_json_and_make_inline(true)
  end

  def preferred_description
    # Either the description from the service description doc, 
    # or the last description annotation.
    
    desc = self.description
    
    if desc.blank?
      desc = self.annotations_with_attribute("description", true).first.try(:value_content)
    end
    
    return desc
  end
  
private

  def generate_json_and_make_inline(make_inline)
    data = {
      "rest_representation" => {
        "content_type" => self.content_type,
        "description" => self.preferred_description,
        "submitter" => ServiceCatalographer::Api.uri_for_object(self.submitter),
        "created_at" => self.created_at.iso8601,
        "archived_at" => self.archived? ? self.archived_at.iso8601 : nil
      }
    }

    unless make_inline
      data["rest_representation"]["self"] = ServiceCatalographer::Api.uri_for_object(self)
			return data.to_json
    else
      data["rest_representation"]["resource"] = ServiceCatalographer::Api.uri_for_object(self)
			return data["rest_representation"].to_json
    end
  end # generate_json_and_make_inline
end
