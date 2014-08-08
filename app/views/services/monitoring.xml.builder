# ServiceCatalographer: app/views/services/monitoring.xml.builder
#
# Copyright (c) 2009, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# <?xml>
xml.instruct! :xml

# <service>
render :partial => "services/api/service", 
       :locals => { :parent_xml => xml,
                    :service => @service,
                    :is_root => true,
                    :show_summary => false,
                    :show_deployments => false,
                    :show_variants => false,
                    :show_monitoring => true,
                    :show_related => true }
