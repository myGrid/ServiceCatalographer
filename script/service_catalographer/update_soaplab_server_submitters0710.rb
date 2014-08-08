#!/usr/bin/env ruby

# ServiceCatalographer: script/service_catalographer/update_soaplab_server_submitters0710.rb
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

require 'optparse'

class UpdateSoaplabServerSubmitters0710

attr_accessor :options
  
  def initialize(args)
    @options = {
      :environment => (ENV['RAILS_ENV'] || "development").dup,
    }
    
    args.options do |opts|

      opts.on("-e", "--environment=name", String,
              "Specifies the environment to run this update script under (test|development|production).",
              "Default: development") { |v| @options[:environment] = v }
    
      opts.separator ""
    
      opts.on("-h", "--help", "Show this help message.") { puts opts; exit }
      
      opts.on("-t", "--test", "Run the script in test mode (so won't actually store anything in the database).") { @options[:test] = true }
    
      opts.parse!
    end
    
    # Start the Rails app
      
    ENV["RAILS_ENV"] = @options[:environment]
    Rails.env = ActiveSupport::StringInquirer.new(@options[:environment])
    
    require File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment')
    
  end
  
  def get_server_info(location)
    server = SoaplabServer.find_by_location(location)
    submitter = server.services.last.submitter
    return {:submitter => submitter, :server => server}
  end
  
  def update_submitter_for_server(server_url)
    server_info = get_server_info(server_url)
    if server_info[:submitter] && server_info[:server]
      server    = server_info[:server]
      submitter = server_info[:submitter]
      unless server.submitter
        server.submitter = submitter
        server.save
        puts "updated submitter for soaplab server #{server.id} to #{submitter.display_name}"
      end
    end
  end

  def update( *params)
    begin
      options = params.extract_options!.symbolize_keys
      options[:server] ||= options.include?(:server)
      options[:all] ||= options.include?(:all)
      
      if options[:server]
        update_submitter_for_server options[:server] 
      elsif options[:all]
        SoaplabServer.all.each do |sls|
          update_submitter_for_server sls.location
        end
      else
        puts "No valid option configured"

      end
    rescue Exception => ex
      puts ""
      puts ">> ERROR: exception occured. Exception: #{ex.class.name} - "
      puts ex.message
      puts ex.backtrace.join("\n")
    end    
  end
end

UpdateSoaplabServerSubmitters0710.new(ARGV.clone).update :all => true 

