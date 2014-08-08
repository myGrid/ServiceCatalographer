# ServiceCatalographer: app/views/service_tests/api/_core_elements.xml.builder
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# <testType>
parent_xml.testType do
  render :partial => "#{service_test.test_type.underscore.pluralize}/api/#{service_test.test_type.underscore}", :locals => { :parent_xml => parent_xml, service_test.test_type.underscore.to_sym => service_test.test }
end

# <dcterms:created>
dcterms_xml_tag parent_xml, :created, service_test.created_at

# <activated>
parent_xml.activated service_test.activated?

# <activatedAt>
if service_test.activated?
  parent_xml.activatedAt service_test.activated_at.iso8601
else 
  parent_xml.activatedAt nil, "xsi:nil" => "true"
end
