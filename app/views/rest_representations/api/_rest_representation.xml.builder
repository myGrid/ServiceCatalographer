# ServiceCatalographer: app/views/rest_representations/api/_rest_representation.xml.builder
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# Defaults:
is_root = false unless local_assigns.has_key?(:is_root)
show_core = true unless local_assigns.has_key?(:show_core)
show_ancestors = false unless local_assigns.has_key?(:show_ancestors)
show_related = false unless local_assigns.has_key?(:show_related)

# <restRepresentation>
parent_xml.tag! "restRepresentation",
                xlink_attributes(uri_for_object(rest_representation), :title => xlink_title(rest_representation)).merge(is_root ? xml_root_attributes : {}),
                :resourceType => "RestRepresentation" do
  
  # Core elements
  if show_core
    render :partial => "rest_representations/api/core_elements", :locals => { :parent_xml => parent_xml, :rest_representation => rest_representation }
  end
  
  # <ancestors>
  if show_ancestors
    render :partial => "rest_representations/api/ancestors", :locals => { :parent_xml => parent_xml, :rest_representation => rest_representation }
  end
  
  # <related>
  if show_related
    render :partial => "rest_representations/api/related_links", :locals => { :parent_xml => parent_xml, :rest_representation => rest_representation }
  end
  
end
