# ServiceCatalographer: app/views/home/status_changes.atom.builder
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

                    
atom_feed :url => status_changes_feed_url(:format => :atom), 
          :root_url => latest_url(:anchor => 'monitoring'),
          :schema_date => "2009" do |feed|
  
  render :partial => 'shared/activity', 
         :locals => { :parent_feed => feed,
                      :feed_title => @feed_title,
                      :entries => activity_entries_for(@activity_logs, :detailed),
                      :item_url => latest_url(:anchor => "monitoring") }
  
end