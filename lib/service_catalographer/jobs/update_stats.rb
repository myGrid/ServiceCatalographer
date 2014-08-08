# ServiceCatalographer: lib/service_catalographer/jobs/update_stats.rb
#
# Copyright (c) 2009, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

module ServiceCatalographer
  module Jobs
    class UpdateStats
      def perform
        ServiceCatalographer::Stats.generate_current_stats
      end    
    end
  end
end