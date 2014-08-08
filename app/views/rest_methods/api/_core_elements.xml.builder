# ServiceCatalographer: app/views/rest_methods/api/_core_elements.xml.builder
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# <dc:title>
dc_xml_tag parent_xml, :title, xlink_title(rest_method)

# <name>
parent_xml.name rest_method.endpoint_name

# <endpointLabel>
parent_xml.endpointLabel rest_method.display_endpoint

#<httpMethodType>
parent_xml.httpMethodType rest_method.method_type

# <urlTemplate>
parent_xml.urlTemplate ServiceCatalographer::Util.generate_rest_endpoint_url_template(rest_method)

# <description>
dc_xml_tag parent_xml, :description, rest_method.preferred_description

# <documentationUrl>
parent_xml.documentationUrl rest_method.documentation_url

# <submitter>
parent_xml.submitter xlink_attributes(uri_for_object(rest_method.submitter), 
                     :title => xlink_title(rest_method.submitter)), 
                     :resourceType => rest_method.submitter_type,
                     :resourceName => rest_method.submitter_name

# <dcterms:created>
dcterms_xml_tag parent_xml, :created, rest_method.created_at

# <archived>
if rest_method.archived?
  parent_xml.archived rest_method.archived_at.iso8601
end