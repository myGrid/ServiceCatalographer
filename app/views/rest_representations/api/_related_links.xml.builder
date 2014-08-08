# ServiceCatalographer: app/views/rest_representations/api/_related_links.xml.builder
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# <related>
parent_xml.related do
  
  # <annotations>
  parent_xml.annotations xlink_attributes(uri_for_object(rest_representation, :sub_path => "annotations"), :title => xlink_title("All annotations on this REST representation")),
                         :resourceType => "Annotations"
  
end