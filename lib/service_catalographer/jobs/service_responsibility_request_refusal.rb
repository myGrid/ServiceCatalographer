# ServiceCatalographer: lib/service_catalographer/jobs/service_responsibility_request_refusal.rb
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

module ServiceCatalographer
  module Jobs
    class ServiceResponsibilityRequestRefusal < Struct.new(:owners, :base_host, :current_user, :req )
      def perform
        owners.each{ |owner| UserMailer.responsibility_request_refusal(owner, base_host, current_user, req).deliver }
      end    
    end
  end
end