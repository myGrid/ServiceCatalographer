# ServiceCatalographer: lib/service_catalographer/jobs/update_urls_to_monitor.rb
#
# Copyright (c) 2009, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

module ServiceCatalographer
  module Jobs
    class UpdateAnnotationPropertiesFull
      def perform
          # Update the table that contains the list of urls on which to perform availability checks
          ServiceCatalographer::SearchByData::update_annotation_properties_full()
        end
      end    
  end
end