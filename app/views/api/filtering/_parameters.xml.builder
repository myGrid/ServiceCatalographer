# ServiceCatalographer: app/views/api/filtering/_parameters.xml.builder
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

filters = @current_filters unless local_assigns.has_key?(:filters)

# <filters>
parent_xml.filters do

  # <group> *
  ServiceCatalographer::Filtering.filter_groups_from(filters, resource_type).each do |g|
    parent_xml.group :name => g.name do
      
      # <type> *
      g.filter_types.each do |t|
        parent_xml.type :name => t.name, :description => t.description, :urlKey => t.key do
          
          # <filter> *
          t.filters.each do |f|
            parent_xml.filter f['name'], :urlValue => f['id']
          end
          
        end
      end
      
    end
  end
end
