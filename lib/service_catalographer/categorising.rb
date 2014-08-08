# ServiceCatalographer: lib/service_catalographer/categories.rb
#
# Copyright (c) 2009, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# Module to carry out the bulk of the logic for categorising of services.

module ServiceCatalographer
  module Categorising
    
    # Goes through the service_categories data and loads them all up into the db 
    # if not already in, or loads new categories or updates existing categories.
    def self.load_data
      unless Category.table_exists?
        msg = "WARNING: cannot load categories data - categories table doesn't exist in the db. Running db:migrate may solve this."
        Rails.logger.warn(msg)
        puts(msg)
        return
      end
      
      begin
        Category.transaction do
          categories_data = YAML.load(IO.read(File.join(Rails.root, 'data', 'service_categories.yml')))
          process_node(categories_data)
        end
      rescue Exception => ex
        msg = "ERROR: Could not load up Categories data. Error message: #{ex.message}."
        Rails.logger.error(msg)
        puts(msg)
      end
    end
    
    def self.category_hierachy_text(category)
      return "" if category.nil?
      
      output = output_category_text(category, true)
      
      category_to_process = category
      
      while category_to_process.has_parent?
        category_to_process = category_to_process.parent
        output = output_category_text(category_to_process) + output
      end
      
      return output
    end
    
    def self.category_with_parent_text(category)
      output = output_category_text(category, true)
      
      if category.has_parent?
        output = output_category_text(category.parent) + output
      end
      
      return output
    end
    
    def self.get_categories_for_service(service)
      anns = service.annotations_with_attribute("category")
      return anns.reject{|a| a.value_type != "Category"}.map{|a| a.value}
    end
    
    # NOTE: this assumes that only Service objects can be annotated with a "category" annotation,
    # and so wouldn't take into account category annotations on sub structure objects.
    def self.user_created_category?(service, category_id, user)
      return false if (user.nil? || !user.is_a?(User))      
      
      cats = Annotation.count(:all,
                              :joins => :attribute,
                              :conditions => { :annotatable_type => "Service",
                                               :annotatable_id => service.id,
                                               :source_type => user.class.name,
                                               :source_id => user.id,
                                               :annotation_attributes =>  { :name => "category" },
                                               :value_type => "Category",
                                               :value_id => category_id })
    
      return cats > 0
    end
    
    def self.number_of_services_for_category(category, recalculate=false)
      return -1 if category.nil?
      
      count = nil
      
      cache_key = CacheHelper.cache_key_for(:services_count_for_category, category.id)
      
      if recalculate
        Rails.cache.delete(cache_key)
      end
      
      # Try and get it from the cache...
      cached_count = Rails.cache.read(cache_key)
      
      if cached_count.nil?
        # It's not in the cache so get the value and store it in the cache...
        
        count = get_service_ids_with_category(category.id).length
        
        # Finally write it to the cache...
        Rails.cache.write(cache_key, count, :expires_in => 10.minutes)
      else
        count = cached_count
      end
      
      return count
    end
    
    # This takes into account subcategories.
    # NOTE: this assumes that only Service objects can be annotated with a "category" annotation,
    # and so wouldn't take into account category annotations on sub structure objects.
    def self.get_service_ids_with_category(category_id, incl_children=true)
      category_ids = [ category_id ] 
      category_ids.concat(get_all_sub_category_ids(category_id)) if incl_children
      
      # NOTE: this query has only been tested to work with MySQL 5.0.x
      sql = [ "SELECT annotations.annotatable_id AS id, annotations.annotatable_type AS type
              FROM annotations 
              INNER JOIN annotation_attributes ON annotations.attribute_id = annotation_attributes.id
              INNER JOIN services ON annotations.annotatable_id = services.id
              WHERE annotation_attributes.name = 'category' 
                AND annotations.annotatable_type = 'Service' 
                AND annotations.value_type = 'Category'
                AND services.archived_at IS NULL
                AND annotations.value_id IN (?)",
              category_ids ]
      
      results = Annotation.connection.select_all(Annotation.send(:sanitize_sql, sql))
      
      return results.map{|r| r['id'].to_i}.uniq
    end
    
    # IMPORTANT: the caching that this employs assumes that the hierarchy never changes.
    # If the hierarchy does change then clear all caches or call this method with recalculate = true.
    def self.get_all_sub_category_ids(category_id, recalculate=false)
      ids = [ ]
      
      cache_key = CacheHelper.cache_key_for(:children_of_category, category_id)
      
      if recalculate
        Rails.cache.delete(cache_key)
      end
      
      # Try and get it from the cache...
      cached_ids = Rails.cache.read(cache_key)
      
      if cached_ids.nil?
        # It's not in the cache so get the value and store it in the cache...
        
        unless (category = Category.find_by_id(category_id)).nil?
          if category.has_children?
            category.children.each do |c|
              ids << c.id
              ids.concat(get_all_sub_category_ids(c.id, recalculate))
            end
          end
        end
        
        # Finally write it to the cache...
        Rails.cache.write(cache_key, ids)
      else
        ids = cached_ids
      end
      
      return ids
    end
    
    protected
    
    def self.process_node(node, current_parent_id=nil)
      node.each do |key, values|
        parent_id, parent_name = split_raw_category(key)
        process_category(parent_id, parent_name, current_parent_id)
        unless values.nil?
          case values
            when Array
              values.each do |child|
                id, name = split_raw_category(child)
                process_category(id, name, parent_id)
              end
            when Hash
              new_current_parent_id = parent_id
              process_node(values, new_current_parent_id)
          end
        end
      end
    end
    
    def self.split_raw_category(c)
      id = ""
      name = ""
      
      name, id = c.split('[')
      name.strip!
      id = id.gsub(']', '').to_i
      
      return [ id, name ]
    end
    
    def self.process_category(id, name, parent_id=nil)
      if (category = Category.find_by_id(id)).nil?
        Util.say("Adding new category to database: '#{name}' (ID: #{id}; Parent ID: #{parent_id})")
        Category.new do |c| 
          c.id = id
          c.name = name
          c.parent_id = parent_id
          c.save
        end
      else
        if category.name != name or category.parent_id != parent_id
          Util.say("Updating category in database: '#{name}' (ID: #{id}; Parent ID: #{parent_id})")
          category.name = name
          category.parent_id = parent_id
          category.save
        end
        category
      end
    end
    
    def self.output_category_text(category, current=false)
      return "" if category.nil?
      if current
        return "<b>#{CGI.escapeHTML(category.name)}</b>"
      else
        "#{CGI.escapeHTML(category.name)}  &gt;  "
      end
    end
    
  end
end
