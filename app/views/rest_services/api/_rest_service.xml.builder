# ServiceCatalographer: app/views/rest_services/api/_rest_service.xml.builder
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# Defaults:
is_root = false unless local_assigns.has_key?(:is_root)
show_core = true unless local_assigns.has_key?(:show_core)
show_deployments = true unless local_assigns.has_key?(:show_deployments)
show_rest_resources = false unless local_assigns.has_key?(:show_rest_resources)
show_rest_methods = false unless local_assigns.has_key?(:show_rest_methods)
show_ancestors = false unless local_assigns.has_key?(:show_ancestors)
show_related = false unless local_assigns.has_key?(:show_related)

# <restService>
parent_xml.tag! "restService",
                xlink_attributes(uri_for_object(rest_service), :title => xlink_title(rest_service)).merge(is_root ? xml_root_attributes : {}),
                :resourceName => display_name(rest_service, false),
                :resourceType => "RestService" do
  
  # Core elements
  if show_core
    render :partial => "rest_services/api/core_elements", :locals => { :parent_xml => parent_xml, :rest_service => rest_service }
  end
  
  # <deployments>
  if show_deployments
    render :partial => "rest_services/api/deployments", :locals => { :parent_xml => parent_xml, :rest_service => rest_service }
  end

  # <resources>
  if show_rest_resources
    render :partial => "rest_services/api/rest_resources", :locals => { :parent_xml => parent_xml, :rest_service => rest_service }
  end
  
  # <methods>
  if show_rest_methods
    render :partial => "rest_services/api/rest_methods", :locals => { :parent_xml => parent_xml, :rest_service => rest_service }
  end
  
  # <ancestors>
  if show_ancestors
    render :partial => "rest_services/api/ancestors", :locals => { :parent_xml => parent_xml, :rest_service => rest_service }
  end
  
  # <related>
  if show_related
    render :partial => "rest_services/api/related_links", :locals => { :parent_xml => parent_xml, :rest_service => rest_service }
  end
  
end
