# ServiceCatalographer: app/views/soap_services/show.xml.builder
#
# Copyright (c) 2009-2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# <?xml>
xml.instruct! :xml

# <soapService>
render :partial => "soap_services/api/soap_service", 
       :locals => { :parent_xml => xml,
                    :soap_service => @soap_service,
                    :is_root => true,
                    :show_deployments => true,
                    :show_operations => true,
                    :show_ancestors => true,
                    :show_related => true }
