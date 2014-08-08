# ServiceCatalographer: app/models/agent.rb
#
# Copyright (c) 2009-2010, University of Manchester, The European Bioinformatics
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

class Agent < ActiveRecord::Base
  if ENABLE_CACHE_MONEY
    is_cached :repository => $cache
    index :name
  end
  
  if ENABLE_TRASHING
    acts_as_trashable
  end
  
  acts_as_annotatable :name_field => :display_name
  acts_as_annotation_source
  
  validates_presence_of :name
  validates_uniqueness_of :name
  
  before_create :generate_default_display_name
  
  has_many :services,
           :as => "submitter"
  
  if USE_EVENT_LOG
    acts_as_activity_logged
  end
  
  def to_json
    generate_json_and_make_inline(false)
  end 
  
  def to_inline_json
    generate_json_and_make_inline(true)
  end

  def annotation_source_name
    self.display_name
  end
  
  def preferred_description
    self.annotations_with_attribute("description", true).first.try(:value_content)
  end
  
  def annotated_service_ids
    service_ids = self.annotations_by.collect do |a|
      ServiceCatalographer::Mapper.map_compound_id_to_associated_model_object_id(ServiceCatalographer::Mapper.compound_id_for(a.annotatable_type, a.annotatable_id), "Service")
    end
    service_ids.compact.uniq
  end
  
private
  
  def generate_default_display_name
    self.display_name = self.name.humanize if self.display_name.blank?
  end

  def generate_json_and_make_inline(make_inline)
    data = {
      "agent" => {
        "name" => ServiceCatalographer::Util.display_name(self),
        "description" => self.preferred_description,
        "created_at" => self.created_at.iso8601
      }
    }
    
    unless make_inline
      data["agent"]["self"] = ServiceCatalographer::Api.uri_for_object(self)
			return data.to_json
    else
      data["agent"]["resource"] = ServiceCatalographer::Api.uri_for_object(self)
			return data["agent"].to_json
    end
  end # generate_json_and_make_inline

end
