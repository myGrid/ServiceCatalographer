# ServiceCatalographer: app/helpers/api_helper.rb
#
# Copyright (c) 2008-2009, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details.

module ApiHelper
  
  include ApplicationHelper
  
  def xml_root_attributes
    { "xmlns" => "http://www.biocatalogue.org/2009/xml/rest",
      "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
      "xsi:schemaLocation" => "http://www.biocatalogue.org/2009/xml/rest " + URI.join(SITE_BASE_HOST, "2009/xml/rest/schema-v1.xsd").to_s,
      "xmlns:xlink" => "http://www.w3.org/1999/xlink",
      "xmlns:dc" => "http://purl.org/dc/elements/1.1/",
      "xmlns:dcterms" => "http://purl.org/dc/terms/" }
  end
  
  def uri_for_path(path, *args)
    ServiceCatalographer::Api.uri_for_path(path, *args)
  end
  
  def uri_for_collection(resource_name, *args)
    ServiceCatalographer::Api.uri_for_collection(resource_name, *args)
  end
  
  def uri_for_object(resource_obj, *args)
    ServiceCatalographer::Api.uri_for_object(resource_obj, *args)
  end
  
  def xml_for_filters(builder, filters, filter_key, results_resource_type)
    return nil if builder.nil? or filters.blank?
    
    filter_key_humanised = ServiceCatalographer::Filtering.filter_type_to_display_name(filter_key).singularize.downcase
    
    filters.each do |f|
      
      attribs = xlink_attributes(generate_include_filter_url(filter_key, f["id"], results_resource_type.underscore), :title => xlink_title("Filter by #{filter_key_humanised}: '#{f['name']}'"))
      attribs.update({
        :urlValue => f["id"],
        :name => f["name"],
        :count => f['count'],
        :resourceType => results_resource_type
      })
      
      builder.filter attribs  do
                 
        xml_for_filters(builder, f["children"], filter_key, results_resource_type)

      end
        
    end
  end
  
  def previous_link_xml_attributes(resource_uri)
    xlink_attributes(resource_uri, :title => xlink_title("Previous page of results"))
  end
  
  def next_link_xml_attributes(resource_uri)
    xlink_attributes(resource_uri, :title => xlink_title("Next page of results"))
  end
  
  def xlink_attributes(resource_uri, *args)
    attribs = { }
    
    attribs_in = args.extract_options!
    
    attribs["xlink:href"] = resource_uri
    
    attribs_in.each do |k,v|
      attribs["xlink:#{k.to_s}"] = v
    end

    return attribs
  end
  
  def xlink_title(item, item_type_name=nil)
    case item
      when String
        return item
      else
        if item_type_name.blank?
          item_type_name = case item
            when User
              "Member"
            else
              item.class.name.titleize
          end
        end
        
        return "#{item_type_name} - #{display_name(item, false)}"
    end
  end
  
  def dc_xml_tag(builder, term, value, *attributes)
    builder.tag! "dc:#{term}", value, attributes
  end
  
  def dcterms_xml_tag(builder, term, value, *attributes)
    # For dates...
    if [ :created, :modified, "created", "modified" ].include?(term)
      value = value.iso8601
    end
    
    builder.tag! "dcterms:#{term}", value, attributes
  end
  
end