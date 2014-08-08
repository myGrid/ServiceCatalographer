# ServiceCatalographer: lib/service_catalographer/jobs/check_url_status
#
# Copyright (c) 2009, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

module ServiceCatalographer
  module Jobs
    class CheckUrlStatus
      def perform
          # check the status of a url using curl
          ServiceCatalographer::Monitoring::CheckUrlStatus.run :all => true
        end
      end    
  end
end