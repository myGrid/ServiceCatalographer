# ServiceCatalographer: lib/tasks/submit_jobs.rake
#
# Copyright (c) 2009, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

namespace :service_catalographer do
  namespace :submit do
    
    desc 'Submits a job to recalculate the total annotation counts (including grouped totals) and cache them (see servicecatalographer_main.rb for cache time)'
    task :calculate_annotation_counts => :environment do
      Delayed::Job.enqueue(ServiceCatalographer::Jobs::CalculateAnnotationCountsJob.new)
    end
    
    desc 'update the list of urls to be monitored'
    task :update_urls_to_monitor => :environment do
      Delayed::Job.enqueue(ServiceCatalographer::Jobs::UpdateUrlsToMonitor.new)
    end 
    
    desc 'check the availability status of a url'
    task :check_url_status => :environment do
      Delayed::Job.enqueue(ServiceCatalographer::Jobs::CheckUrlStatus.new)
    end 
    
    desc 'Submits a job to update the search query suggestions text file'
    task :update_search_query_suggestions => :environment do
      Delayed::Job.enqueue(ServiceCatalographer::Jobs::UpdateSearchQuerySuggestions.new)
    end
    
    desc 'Submits a job to refresh the stats data used in the /statistics page'
    task :refresh_stats => :environment do
      ServiceCatalographer::Stats.submit_job_to_refresh_stats
    end
    
    desc 'Submits a job to fully update annotation properties'
    task :update_annotation_properties_full => :environment do
      Delayed::Job.enqueue(ServiceCatalographer::Jobs::UpdateAnnotationPropertiesFull.new)
    end
    
    desc 'Submits a job to run the service updater for all services in the ServiceCatalogue'
    task :run_service_updater_for_all => :environment do
      Delayed::Job.enqueue(ServiceCatalographer::Jobs::RunServiceUpdaterForAll.new)
    end
    
  end
end