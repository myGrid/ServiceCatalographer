# ServiceCatalographer: lib/service_catalographer/jobs/service_responsibility_request_cancellation.rb
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

module ServiceCatalographer
  module Jobs
    class ServiceResponsibilityRequestCancellation < Struct.new(:owners, :base_host, :service, :current_user, :req )
      def perform
        owners.each{ |owner| UserMailer.responsibility_request_cancellation(owner, base_host, service, current_user, req).deliver }
      end    
    end
  end
end