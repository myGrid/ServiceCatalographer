# ServiceCatalographer: app/models/service.rb
#
# Copyright (c) 2008-2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details


class Service < ActiveRecord::Base
  if ENABLE_CACHE_MONEY
    is_cached :repository => $cache
    index :unique_code
    index :name
    index [ :submitter_type, :submitter_id ]
  end
  
  after_create :tweet_create, :responsible_create
    
  if ENABLE_TRASHING
    acts_as_trashable
  end
  
  acts_as_annotatable :name_field => :name
  
  acts_as_favouritable
  
  acts_as_archived
  
  has_many :relationships, 
           :as => :subject, 
           :dependent => :destroy
  
  has_many :service_versions, 
           :dependent => :destroy,
           :order => "created_at ASC"
  
  has_many :service_deployments, 
           :dependent => :destroy
  
  has_many :service_tests, 
           :dependent => :destroy
  
  has_many :responsibility_requests,
           :as => :subject,
           :dependent => :destroy
  
  has_many :service_responsibles,
           :dependent => :destroy
  
  has_submitter
  
  before_validation :generate_unique_code, :on => :create
  
  attr_protected :unique_code
  
  validates_presence_of :name, :unique_code
  
  validates_uniqueness_of :unique_code
  
  validates_associated :service_versions
  
  validates_associated :service_deployments
  
  
  validates_existence_of :submitter   # User must exist in the db beforehand.
  
  if ENABLE_SEARCH
    searchable do
      text :name, :boost => 6.0
      text :unique_code
      text :submitter_name
    end
  end
  
  if USE_EVENT_LOG
    acts_as_activity_logged(:models => { :culprit => { :model => :submitter } })
  end
  
  def self.latest(limit=10)
    # Old Rails 2 style
    #self.all(              :order => "created_at DESC",
    #                       :limit => limit)
    self.order("created_at DESC").limit(limit)
  end
  
  def to_json
    generate_json_with_collections("default")
  end 
  
  def to_inline_json
    generate_json_with_collections(nil, true)
  end
  
  def to_custom_json(collections)
    generate_json_with_collections(collections)
  end


  def as_csv
    unique_id = self.unique_code
    name = self.name
    provider = self.list_of("providers").first["service_provider"]["name"]
    location = join_array(self.list_of("locations").first.values_at(*["city", "country"]))
    submitter = self.submitter.display_name
    base_url = self.list_of("endpoints").first["endpoint"]
    doc_url =  join_array(self.list_of("documentation_url"))
    description = join_array(self.list_of("description"))
    license = join_array(self.list_of("license"))
    costs = join_array(self.list_of("cost"))
    usage_conditions = join_array(self.list_of("usage_condition"))
    contact = join_array(self.list_of("contact"))
    publications = join_array(self.list_of("publication"))
    citations = join_array(self.list_of("citation"))
    annotations = join_array(self.get_service_tags)
    categories = []
    self.list_of("category").each{|x| categories << x["name"] }
    categories = join_array categories

    [unique_id, name, provider,location,submitter,base_url,
     doc_url, description, license, costs, usage_conditions, contact,
     publications, citations, annotations, categories]
  end

  def join_array array
    array.compact!
    array.delete('')

    if array.nil? || array.empty? then
      return ''
    else
      if array.count > 1 then
        return array.join(';')
      else
        return array.first.to_s
      end
    end
  end

#  def to_param
#    "#{self.id}-#{self.unique_code}"
#  end


  def latest_version
    self.service_versions.last
  end
  
  def latest_deployment
    self.service_deployments.last
  end
  
  def service_version_instances
    self.service_versions.collect{|sv| sv.service_versionified}    
  end
  
  def service_version_instances_by_type(type_model_name)
    # Old Rails 2
    #type_model_name.constantize.all(                                     :conditions => { :service_versions => { :service_id => self.id } },
    #                                 :joins => [ :service_version ])
    type_model_name.constantize.joins(:service_version).where(:service_versions => {:service_id => self.id})
  end
  
  # Gets an array of all the service types that this service has (as part of it's versions).
  def service_types
    types = self.service_versions.collect{|sv| sv.service_versionified.service_type_name}.uniq
    types << "Soaplab" unless self.soaplab_server.nil?
    return types
  end
  
  def description
    self.latest_version.service_versionified.description
  end
  
  def preferred_description
    # Either the description from the service description doc, 
    # or the last description annotation.
    
    desc = self.description
    
    if desc.blank?
      desc = self.latest_version.service_versionified.annotations_with_attribute("description", true).last.try(:value_content)
    end
    
    return desc
  end
  
  # Gets an array of all the ServiceProviders
  def providers
    self.service_deployments.collect{|sd| sd.provider}.uniq
  end
  
  def views_count
    # NOTE: this query has only been tested to work with MySQL 5.0.x
    sql = "SELECT COUNT(*) AS count 
          FROM activity_logs
          WHERE action = 'view' AND activity_logs.activity_loggable_type = 'Service' AND activity_logs.activity_loggable_id = '#{self.id}'"
    
    return ActiveRecord::Base.connection.select_all(sql)[0]['count'].to_i
  end
  
  # Currently finds all services that have same (or parent) categories as this service.
  def similar_services(limit=10)
    services = [ ]
    
    sql = "SELECT categories.id AS category_id
          FROM annotations
          INNER JOIN annotation_attributes ON annotations.attribute_id = annotation_attributes.id
          INNER JOIN categories ON categories.id = annotations.value_id AND annotations.value_type = 'Category'
          WHERE annotation_attributes.name = 'category' 
            AND annotations.annotatable_type = 'Service' 
            AND annotations.annotatable_id = #{self.id}"
    
    results = ActiveRecord::Base.connection.select_all(sql)
    
    unless results.blank?
      category_ids = results.map{|r| r['category_id'].to_i}
      
      final_category_ids = category_ids.clone
      
      # Add parents
      category_ids.each do |c_id|
        unless (category = Category.find_by_id(c_id)).nil?
          while category.has_parent?
            category = category.parent 
            final_category_ids << category.id
          end
        end
      end

      service_ids = [ ]
      
      final_category_ids.each do |c_id|
        service_ids.concat(ServiceCatalographer::Categorising.get_service_ids_with_category(c_id, false))
      end
      
      service_ids = service_ids.uniq.reject{|i| i == self.id}

      # Old Rails 2 style
      #services = Service.all(:conditions => { :id => service_ids[0...limit] })
      services = Service.where(:id => service_ids[0...limit])
    end
    
    return services
  end
  
  # IF this is Service is part of a Soaplab Server then this method returns that SoaplabServer entry.
  # Otherwise it returns nil, which indicates that this Service is not part of a Soaplab Server.
  def soaplab_server
    # Old Rails 2 style
    #rel = Relationship.first(
    #    :conditions => { :subject_type => "Service",
    #                     :subject_id => self.id,
    #                     :predicate => "ServiceCatalogue:memberOf",
    #                     :object_type => "SoaplabServer" })
    rel = Relationship.where(:subject_type => "Service",
                                             :subject_id => self.id, 
                                             :predicate => "ServiceCatalogue:memberOf",
                                             :object_type => "SoaplabServer").first
    rel.nil? ? rel : rel.object
  end
  
  def test_scripts(options={})
    scripts = service_test_instances_by_type('TestScript')
    if options[:active_only]
      return scripts.collect{|s| s if s.service_test.activated? }.compact
    end
    scripts
  end
  
  def service_tests_by_type(type)
    # Old Rails 2 style
    #ServiceTest.all(:conditions => {:test_type => type, :service_id => self.id})
    ServiceTest.where(:test_type => type, :service_id => self.id)
  end
  
  # e.g. To find all test scripts:  service_test_instances_by_type('TestScript')
  def service_test_instances_by_type(type)
    service_tests_by_type(type).collect{|st| st.test}.compact
  end
  
  # This updates the submitter as well as the submitter of this service as well 
  # as all ServiceDeployment and ServiceVersions underneath it.
  # NOTE: USE THIS WITH CAUTION AS YOU ARE ASSUMING THAT ONE SUBMITTER SUBMITTED EVERYTHING. 
  def update_service_structure_submitter(new_submitter)
    return false if new_submitter.nil?
    
    status = true
    
    unless self.submitter == new_submitter
      self.submitter = new_submitter
      status = status && self.save
    end
    
    self.service_versions.each do |sv|
      unless sv.submitter == new_submitter
        sv.submitter = new_submitter
        status = status && sv.save
      end
    end
    
    self.service_deployments.each do |sd|
      unless sd.submitter == new_submitter
        sd.submitter = new_submitter
        status = status && sd.save
      end
    end
    
    return status
  end
  
  def latest_status
    ServiceCatalographer::Monitoring::ServiceStatus.new(self)
  end
  
  def latest_test_results_for_all_service_tests(options ={})
    results = self.service_tests.map{ |st| st.latest_test_result if st.activated? }.compact
    if options[:all]
      return self.service_tests.map{ |st| st.latest_test_result  }.compact
    end
    results
  end
  
  # Either return the creation time of the earliest test result
  # for all the service tests or return nil if no test results exist
  def monitored_since
    first_results = self.service_tests.collect{|st| st.test_results.first}.compact
    unless first_results.first.nil?
      return first_results.sort_by{|r| r.created_at}.first.created_at 
    end
    return nil
  end
  
  # Curators and submitters are given full permissions on the 
  # service by adding them to the set of those responsible to
  # manage the service the service by default.  
  def all_responsibles
    # Old Rails 2 style
    #curators = User.all(:conditions => {:role_id => [ 1, 2 ]})
    curators = User.where(:role_id => [ 1, 2 ])
    responsibles = self.service_responsibles.collect{|r| r.user if r.status='active'}.compact
    responsibles << self.submitter if self.submitter_type == "User"
    responsibles.concat(curators)
    return responsibles.uniq
  end
  
  def pending_responsibility_requests(limit=5)
    # Old Rails 2 style
    #reqs = ResponsibilityRequest.all(:conditions => {:subject_type => self.class.name,
    #                                                        :subject_id => self.id,
    #                                                        :status => 'pending'}, :limit => limit)
    reqs = ResponsibilityRequest.where(:subject_type => self.class.name,
                                           :subject_id => self.id,
                                           :status => 'pending').limit(limit)
    return reqs
  end
  
  def run_service_updater!
    # Run SoapService#update_from_latest_wsdl! for all SoapService variants of this Service
    self.service_version_instances_by_type("SoapService").each do |soap_service|
      # The soap_service object is read only so need to refetch the object...
      SoapService.find(soap_service.id).update_from_latest_wsdl!
    end
  end
  
  # Currently only gets the associated object IDs for:
  # - ServiceDeployments
  # - ServiceVersions
  # - SoapService
  # - RestService
  #
  # Note that this is eternally cached.
  #
  # FIXME: this needs to take into account when any new objects of the 
  # type above are added to the Service.
  def associated_object_ids(cache_refresh=false)
    object_ids = nil
      
    cache_key = ServiceCatalographer::CacheHelper.cache_key_for(:associated_object_ids, "Service", self.id)
  
    if cache_refresh
      Rails.cache.delete(cache_key)
    end
    
    # Try and get it from the cache...
    object_ids = Rails.cache.read(cache_key)
    
    if object_ids.nil?
      
      # It's not in the cache so get the values and store it in the cache...
      
      object_ids = { }
      
      object_ids["ServiceDeployments"] = self.service_deployments.map { |sd| sd.id }
      object_ids["ServiceVersions"] = self.service_versions.map { |sv| sv.id }
      object_ids["SoapServices"] = self.service_version_instances_by_type("SoapService").map { |ss| ss.id }
      object_ids["RestServices"] = self.service_version_instances_by_type("RestService").map { |rs| rs.id }
      
      # Finally write it to the cache...
      Rails.cache.write(cache_key, object_ids)
      
    end
    
    return object_ids
  end
  
  def annotations_activity_logs(since, limit=100)
    obj_ids = self.associated_object_ids
    # Old Rails 2 style
    #ActivityLog.all(      :conditions => [ "action = 'create' AND activity_loggable_type = 'Annotation' AND (
    #                   (activity_loggable_type = 'Service' AND activity_loggable_id = ?) OR (referenced_type = 'Service' AND referenced_id = ?) OR
    #                   (activity_loggable_type = 'ServiceDeployment' AND activity_loggable_id IN (?)) OR (referenced_type = 'ServiceDeployment' AND referenced_id IN (?)) OR
    #                   (activity_loggable_type = 'ServiceVersion' AND activity_loggable_id IN (?)) OR (referenced_type = 'ServiceVersion' AND referenced_id IN (?)) OR
    #                   (activity_loggable_type = 'SoapService' AND activity_loggable_id IN (?)) OR (referenced_type = 'SoapService' AND referenced_id IN (?)) OR
    #                   (activity_loggable_type = 'RestService' AND activity_loggable_id IN (?)) OR (referenced_type = 'RestService' AND referenced_id IN (?))
    #                   ) AND created_at >= ?",
    #                   "Service",
    #                   self.id,
    #                   (obj_ids["ServiceDeployments"] || []),
    #                   (obj_ids["ServiceDeployments"] || []),
    #                   (obj_ids["ServiceVersions"] || []),
    #                   (obj_ids["ServiceVersions"] || []),
    #                   (obj_ids["SoapServices"] || []),
    #                   (obj_ids["SoapServices"] || []),
    #                   (obj_ids["RestServices"] || []),
    #                   (obj_ids["RestServices"] || []),
    #                   since ],
    #  :order => "created_at DESC",
    #  :limit => limit)
    ActivityLog.where("action = 'create' AND activity_loggable_type = 'Annotation' AND (
                       (activity_loggable_type = 'Service' AND activity_loggable_id = ?) OR (referenced_type = 'Service' AND referenced_id = ?) OR
                       (activity_loggable_type = 'ServiceDeployment' AND activity_loggable_id IN (?)) OR (referenced_type = 'ServiceDeployment' AND referenced_id IN (?)) OR
                       (activity_loggable_type = 'ServiceVersion' AND activity_loggable_id IN (?)) OR (referenced_type = 'ServiceVersion' AND referenced_id IN (?)) OR
                       (activity_loggable_type = 'SoapService' AND activity_loggable_id IN (?)) OR (referenced_type = 'SoapService' AND referenced_id IN (?)) OR
                       (activity_loggable_type = 'RestService' AND activity_loggable_id IN (?)) OR (referenced_type = 'RestService' AND referenced_id IN (?))
                       ) AND created_at >= ?",
                                           "Service",
                                           self.id,
                                           (obj_ids["ServiceDeployments"] || []),
                                           (obj_ids["ServiceDeployments"] || []),
                                           (obj_ids["ServiceVersions"] || []),
                                           (obj_ids["ServiceVersions"] || []),
                                           (obj_ids["SoapServices"] || []),
                                           (obj_ids["SoapServices"] || []),
                                           (obj_ids["RestServices"] || []),
                                           (obj_ids["RestServices"] || []),
                                           since).order("created_at DESC").limit(limit)
  end
  
  def activate_service_tests!
    self.service_tests.each do |t|
      if !t.activated?
        t.activate!
      end
    end
  end
  
  def deactivate_service_tests!
    self.service_tests.each do |t|
      if t.activated?
        t.deactivate!
      end
    end
  end
  
  def availability
    return 0 if self.service_tests.count == 0
    successes = self.service_tests.collect{|st| st.success_rate}.compact
    return (successes.sum/self.service_tests.count).to_i
  end
  
  # Submit a job to submit this service in the 
  # background.
  def submit_delete_job
    begin
      Delayed::Job.enqueue(ServiceCatalographer::Jobs::ServiceDelete.new(self), :priority => 0, :run_at => 5.seconds.from_now)
      return true
    rescue Exception => ex
      logger.error(ex.to_s)
      return false
    end
    return false
  end
  
  def has_capacity_for_new_monitoring_endpoint?
    anns = self.annotations_with_attribute("monitoring_endpoint", true)
    return anns.empty? 
  end
  
  def data_example_annotations
    data = [ ]
    
    self.service_versions.each do |sv|
      case sv.service_versionified_type
        when "SoapService"
          sv.service_versionified.soap_operations.each do |so|
            (so.soap_inputs + so.soap_outputs).each do |p|
              data << { 
                :resource => p,
                :type_of_data => "Example data",
                :annotations => p.annotations_with_attribute("example_data")
              }
            end
          end
        when "RestService"
          sv.service_versionified.rest_methods.each do |rm|
            data << {
              :resource => rm,
              :type_of_data => "Example endpoint",
              :annotations => rm.annotations_with_attribute("example_endpoint")
            }
            
            rm.rest_method_parameters.each do |rmp|
              data << {
                :resource => rmp.rest_parameter,
                :type_of_data => "Example data",
                :annotations => rmp.rest_parameter.annotations_with_attribute("example_data")
              } unless rmp.rest_parameter.nil?
            end
            
            rm.rest_method_representations.each do |rmr|
              data << {
                :resource => rmr.rest_representation,
                :type_of_data => "Example data",
                :annotations => rmr.rest_representation.annotations_with_attribute("example_data"),
              } unless rmr.rest_representation.nil?
            end
          end
      end
    end
    
    return data
  end


  def list_of(tags)
    list_for_attribute(tags)
  end

  protected

  def get_service_tags
    list = []
    ServiceCatalographer::Annotations.get_tag_annotations_for_annotatable(self).each { |ann| list << ann.value_content }
    return list
  end


  def generate_unique_code
    salt = rand 1000000
    
    if self.name.blank?
      errors.add_to_base("Failed to generate the unique code for the Service. The name of the service has not been set yet.")
      return false
    else
      code = "#{Slugalizer.slugalize(self.name)}_#{salt}"
      
      if Service.exists?(:unique_code => code)
        generate_unique_code
      else
        self.unique_code = code
      end
    end
  end
  
  def tweet_create
    if ENABLE_TWITTER
      ServiceCatalographer::Util.say "Called Service#tweet_create to submit job to tweet"
      msg = "New #{self.service_types[0]} service: #{ServiceCatalographer::Util.display_name(self)} - #{ServiceCatalographer::Api.uri_for_object(self)}"
      Delayed::Job.enqueue(ServiceCatalographer::Jobs::PostTweet.new(msg), :priority => 0, :run_at => 5.seconds.from_now)
    end
  end
  
private

  def generate_json_with_collections(collections, make_inline=false)
    collections ||= []

    allowed = %w{ deployments variants monitoring }
    
    if collections.class==String
      collections = case collections.strip.downcase
                      when "deployments"
                        %w{ deployments }
                      when "variants"
                        %w{ variants }
                      when "monitoring"
                        %w{ monitoring }
                      when "summary"
                        %w{ summary }
                      when "default"
                        %w{ deployments variants }
                      else []
                    end
    else
      collections.each { |x| x.downcase! }
      collections.uniq!
      collections.reject! { |x| !allowed.include?(x) }
    end
        
    data = {
      "service" => {
        "name" => ServiceCatalographer::Util.display_name(self),
        "description" => self.preferred_description,
        "submitter" => ServiceCatalographer::Api.uri_for_object(self.submitter),
        "created_at" => self.created_at.iso8601,
        "archived_at" => self.archived? ? self.archived_at.iso8601 : nil,
        "service_technology_types" => self.service_types,
        "latest_monitoring_status" => ServiceCatalographer::Api::Json.monitoring_status(self.latest_status)
      }
    }

    collections.each do |collection|
      case collection.downcase
        when "monitoring"
          data["service"]["service_tests"] = ServiceCatalographer::Api::Json.collection(self.service_tests)
        when "variants"
          versions = []
          self.service_versions.each{ |v| versions << v.service_versionified }
          data["service"]["variants"] = ServiceCatalographer::Api::Json.collection(versions)
        when "deployments"
          data["service"]["deployments"] = ServiceCatalographer::Api::Json.collection(self.service_deployments)
        when "summary"
          metadata_counts = {}
          ServiceCatalographer::Annotations.metadata_counts_for_service(self).each { |meta_type, meta_count| metadata_counts.merge!("by_#{meta_type}" => meta_count) }
                    
          data["service"]["summary"] = {
            "counts" => {
              "deployments" => self.service_deployments.count,
              "variants" => self.service_versions.count,
              "metadata" => metadata_counts,
              "favourites" => self.favourites.count,
              "view" => self.views_count
            },
            "alternative_names" => list_for_attribute("alternative_name"),
            "categories" => list_for_attribute("category"),
            "providers" => list_for_attribute("providers"),
            "endpoints" => list_for_attribute("endpoints"),
            "wsdls" => list_for_attribute("wsdls"),
            "locations" => list_for_attribute("locations"),
            "documentation_urls" => list_for_attribute("documentation_url"),
            "descriptions" => list_for_attribute("description"),
            "tags" => list_for_attribute("tag"),
            "cost" => list_for_attribute("cost"),
            "licenses" => list_for_attribute("license"),
            "usage_conditions" => list_for_attribute("usage_condition"),
            "contacts" => list_for_attribute("contact"),
            "publications" => list_for_attribute("publication"),
            "citations" => list_for_attribute("citation")
          }
      end
    end

    unless make_inline
      data["service"]["self"] = ServiceCatalographer::Api.uri_for_object(self)
			return data.to_json
    else
      data["service"]["resource"] = ServiceCatalographer::Api.uri_for_object(self)
			return data["service"].to_json
    end
  end # generate_json_with_collections

  def list_for_attribute(attr)
    list = []
    
    case attr.downcase
      when "providers"
        self.service_deployments.each { |item| list << item.provider }
        list = ServiceCatalographer::Api::Json.collection(list, false)
      when "endpoints"
        self.service_deployments.each { |item| list << { "endpoint" => item.endpoint } }
      when "wsdls"
        soaps = service_version_instances_by_type("SoapService")
        soaps.each { |item| list << item.wsdl_location } unless soaps.blank?
      when "locations"
        self.service_deployments.each { |item| list << ServiceCatalographer::Api::Json.location(item.country, item.city) }
      when "tag"
        ServiceCatalographer::Annotations.get_tag_annotations_for_annotatable(self).each { |ann| list << { "name" => ann.value_content } }
        list = ServiceCatalographer::Api::Json.tags_collection(list)
      when "category"
        self.annotations_with_attribute("category").each do |ann| 
          list << JSON(ann.value.to_countless_inline_json) if ann.value_type == "Category"
        end
      else
        ServiceCatalographer::Annotations.annotations_for_service_by_attribute(self, attr).each { |ann| list << ann.value_content }
    end
    
    return list
  end
  
  # This give the submitter the possibility to 
  # to subscribe to notifications from this 
  # service. Submitters are no longer automatically
  # added to the notification list for the services.
  # Rather they now need to activate a subscription
  # through their user profile.
  def responsible_create
    begin
      ServiceResponsible.create(:user_id => self.submitter.id, :service_id => self.id, :status =>"inactive")
    rescue Exception => ex
      logger.error(ex)
      return false
    end
    return true
  end
  
end
