# ServiceCatalographer: app/views/services/api/_result_item.xml.builder
#
# Copyright (c) 2009-2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# <service>
render :partial => "services/api/service", 
       :locals => { :parent_xml => parent_xml,
                    :service => service,
                    :show_summary => @api_params[:include].include?("all") || @api_params[:include].include?("summary"),
                    :show_deployments => @api_params[:include].include?("all") || @api_params[:include].include?("deployments"),
                    :show_variants => @api_params[:include].include?("all") || @api_params[:include].include?("variants"),
                    :show_monitoring => @api_params[:include].include?("all") || @api_params[:include].include?("monitoring"),
                    :show_related => true }
