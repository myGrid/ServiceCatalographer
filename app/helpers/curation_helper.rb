# BioCatalogue: app/helpers/curation_helper.rb
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details.

module CurationHelper
  
 def sort_li_class_helper(param, order)
    result = 'class="sortup"' if (params[:sort_by] == param && params[:sort_order] == order)
    result = 'class="sortdown"' if (params[:sort_by] == param && params[:sort_order] == reverse_order(order))  
    return result
 end

 def latest_csv_export
   directory = Rails.root.join('data',"#{Rails.env}-csv-exports")
   unless File.directory?(directory)
     Dir.mkdir(directory)
   end
   files = Dir.entries(directory)
   files = files.select{|file| file.match("csv_export-") }
   latest_file = files.sort.last
   if !latest_file.nil? && latest_file != ""
     return "#{directory}/#{latest_file}"
   else
     return nil
   end
 end

 def time_of_export file_name
   file_name.gsub!(/\D+/, '')
   file_name.to_time.strftime("%e %b %Y %H:%M:%S %Z")
 end


 def curation_sort_link_helper(text, param, order)
    key   = param
    order = order
    order = reverse_order(params[:sort_order]) if params[:sort_by] == param
    params.delete(:page) # reset page
    options = {
      :url => {:action => 'annotation_level', :params => params.merge({:sort_by => key , :sort_order => order})}, #:page =>param[:page]
      :update => 'annotation_level',
      :before => "Element.show('spinner')",
      :success => "Element.hide('spinner')"
      }
    html_options = {
      :title => "Sort by this field",
      :href => url_for(:action => 'annotation_level', :params => params.merge({:sort_by => key, :sort_order => order })) #:page => params[:page]
      }
    link_to_with_callbacks(text, options, html_options.merge(:remote => true))
  end
  
  def reverse_order(order)
    orders ={'asc' => 'desc', 'desc' => 'asc'}
    return orders[order]
  end
  
  # convert to an html nested list
  def from_list_to_html(list, depth_to_traverse=1000, start_depth=0)
    depth = start_depth
    if list.is_a?(Array) && !list.empty?
      str =''
      str << '<ul>'
      depth += 1
      list.each do |value|
        unless depth > depth_to_traverse
          str << "<li> #{value} </li> "
          if value.is_a?(Array) 
            str << from_hash_to_html(value, depth_to_traverse, depth)
          end
        end
      end
      str << '</ul> '
      return str.html_safe
    end
    return ''
  end
end
