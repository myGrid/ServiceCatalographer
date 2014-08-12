# ServiceCatalographer: app/views/api/show.xml.builder
#
# Copyright (c) 2009-2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# <?xml>
xml.instruct! :xml

# <servicecatalogue>
xml.tag! "servicecatalogue",
         xlink_attributes(uri_for_collection("/"), :title => "The ServiceCatalogue"),
         xml_root_attributes,
         :version => ServiceCatalographer::VERSION,
         :apiVersion => ServiceCatalographer::API_VERSION,
         :resourceType => "ServiceCatalogue" do
  
  # <documentation>
  xml.documentation xlink_attributes("http://dev.mygrid.org.uk/wiki/display/servicecatalographer/API", :title => "Documentation for the ServiceCatalographer's API")
  
  # <collections>
  xml.collections do
    
    # <agents>
    xml.agents xlink_attributes(uri_for_collection("agents"), :title => xlink_title("Agents index")),
                 :resourceType => "Agents"

    # <annotationAttributes>
    xml.annotationAttributes xlink_attributes(uri_for_collection("annotation_attributes"), :title => xlink_title("Annotation Attributes index")),
                 :resourceType => "AnnotationAttributes"
    
    # <annotations>
    xml.annotations xlink_attributes(uri_for_collection("annotations"), :title => xlink_title("Annotations index")),
                 :resourceType => "Annotations"

    # <categories>
    xml.categories xlink_attributes(uri_for_collection("categories"), :title => xlink_title("Categories index")),
                 :resourceType => "Categories"

    # <registries>
    xml.registries xlink_attributes(uri_for_collection("registries"), :title => xlink_title("Registries index")),
                 :resourceType => "Registries"

    # <restMethods>
    xml.restMethods xlink_attributes(uri_for_collection("rest_methods"), :title => xlink_title("REST Methods index")),
                 :resourceType => "RestMethods"

    # <restResources>
    xml.restResources xlink_attributes(uri_for_collection("rest_resources"), :title => xlink_title("REST Resources index")),
                 :resourceType => "RestResources"

    # <restServices>
    xml.restServices xlink_attributes(uri_for_collection("rest_services"), :title => xlink_title("REST Services index")),
                 :resourceType => "RestServices"

    # <search>
    xml.search xlink_attributes(uri_for_collection("search"), :title => xlink_title("Search everything in the ServiceCatalogue")),
               :resourceType => "Search"

    # <serviceProviders>
    xml.serviceProviders xlink_attributes(uri_for_collection("service_providers"), :title => xlink_title("Service Providers index")),
                 :resourceType => "ServiceProviders"

    # <services>
    xml.services xlink_attributes(uri_for_collection("services"), :title => xlink_title("Services index")),
                 :resourceType => "Services"

    # <soapOperations>
    xml.soapOperations xlink_attributes(uri_for_collection("soap_operations"), :title => xlink_title("SOAP operations index")),
                 :resourceType => "SoapOperations"

    # <soapServices>
    xml.soapServices xlink_attributes(uri_for_collection("soap_services"), :title => xlink_title("SOAP Services index")),
                 :resourceType => "SoapServices"

    # <tags>
    xml.tags xlink_attributes(uri_for_collection("tags"), :title => xlink_title("Tags index")),
                 :resourceType => "Tags"

    # <testResults>
    xml.testResults xlink_attributes(uri_for_collection("test_results"), :title => xlink_title("Test Results index")),
                 :resourceType => "TestResults"
    
    # <users>
    xml.users xlink_attributes(uri_for_collection("users"), :title => xlink_title("Users index")),
                 :resourceType => "Users"
    
    # <filters>
    xml.filters do

      # <annotations>
      xml.annotations xlink_attributes(uri_for_collection("annotations/filters"), :title => xlink_title("Filters for the annotations index")),
                          :resourceType => "Filters" 

      # <restMethods>
      xml.restMethods xlink_attributes(uri_for_collection("rest_methods/filters"), :title => xlink_title("Filters for the REST methods index")),
                          :resourceType => "Filters" 
      
      # <services>
      xml.services xlink_attributes(uri_for_collection("services/filters"), :title => xlink_title("Filters for the services index")),
                          :resourceType => "Filters"  
      
      # <soapOperations>
      xml.soapOperations xlink_attributes(uri_for_collection("soap_operations/filters"), :title => xlink_title("Filters for the SOAP operations index")),
                          :resourceType => "Filters" 
                          
    end
    
  end
  
end