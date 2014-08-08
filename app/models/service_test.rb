# ServiceCatalographer: app/models/service_test.rb
#
# Copyright (c) 2009-2010, University of Manchester, The European Bioinformatics
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details


class ServiceTest < ActiveRecord::Base
  if ENABLE_CACHE_MONEY
    is_cached :repository => $cache
    index :test_type
    index [ :test_type, :test_id, :service_id ]
  end
  
  belongs_to :service
  
  belongs_to :test,
             :polymorphic => true,
             :dependent => :destroy
  
  has_many :test_results, 
           :dependent => :destroy
  
  has_many :relationships, :as => :subject, :dependent => :destroy
  
  validates_presence_of :service_id, :test
                        
  validates_associated :test
  
  if ENABLE_TRASHING
    acts_as_trashable
  end
  
  if USE_EVENT_LOG
    acts_as_activity_logged(:models => { :referenced => { :model => :service } })
  end
  
  def latest_test_result
    self.test_results.last || TestResult.new(:result => -1, :created_at => Time.now)
  end
  
  def recent_test_results(limit=5)
    TestResult.all(:conditions => ["service_test_id=?", self.id],
                          :limit => limit, :order => 'created_at DESC') || [ TestResult.new(:result => -1, :created_at => Time.now) ]
  end
  
  def latest_status
    ServiceCatalographer::Monitoring::ServiceTestStatus.new(self)
  end
  
  def activated?
    !self.activated_at.blank?
  end
  
  def activate!
    unless !self.activated_at.blank? 
      begin
        self.activated_at = Time.now
        self.save!
        return true
      rescue Exception => ex
        logger.error("Failed to activate service_test #{self.id}. Exception")
        logger.error(ex)
        return false
      end
    end
    logger.error("Service test with #{self.id} was already activated !")
    return false
  end
  
  def deactivate!
    unless self.activated_at.blank?
      begin
        self.activated_at = nil
        self.save!
        return true
      rescue Exception => ex
        logger.error("Failed to deactivate service_test #{self.id}. Exception:")
        logger.error(ex)
        return false
      end
    end
    logger.error("Service test with #{self.id} was already deactivated. Exception:")
    return false
  end
  
  
  def status_changed?
    results = self.test_results.last(2)
    case results.length
      when 0
        return false
      when 1
        return true
      when 2
        stat1 = ServiceCatalographer::Monitoring::TestResultStatus.new(results[0])
        stat2 = ServiceCatalographer::Monitoring::TestResultStatus.new(results[1])
        if stat1.label == stat2.label
          return false
        end
        return true
    end
    
  end
  
  def monitored_since(format=true)
    unless self.test_results.empty?
      return self.test_results.first.created_at.strftime("%A %B %d , %Y") if format
      return self.test_results.first.created_at
    end
    return nil
  end
  
  def failing_since
    unless self.test_results.empty?
      last_result = self.test_results.last
      
      if last_result.result > 0
        return last_result.created_at if self.test_results.count == 1
        
        last_success = last_successful_test_result
        
        unless last_success.nil?
          next_failed = TestResult.first(                                        :conditions => ["service_test_id=? AND result >= 1 AND created_at > ? ", self.id, last_success.created_at],
                                        :order => 'created_at ASC')
        
          if next_failed.nil?
            ServiceCatalographer::Util.yell "ServiceTest#failing_since (for ServiceTest with ID: #{self.id}) caused an error that SHOULD not have happened!" +
                      "Check the integrity of the TestResults collection for this ServiceTest!"
          else
            return next_failed.created_at
          end
        end
        
        return self.test_results.first.created_at
      end
    end
    
    return nil
  end
  
  def last_successful_test_result
    TestResult.first(
                    :conditions => ["service_test_id=? AND result=0 ", self.id], 
                    :order => 'created_at DESC')
  end
  
  def to_json
    generate_json_with_collections("default")
  end
  
  def to_inline_json
    generate_json_with_collections(nil, true)
  end
  
  #synonym to activated
  def enabled?
    return activated?
  end
  
  def archived?
    return archived_at
  end
  
  def pass_count
    TestResult.count(:conditions => ["service_test_id=? AND result = ?", self.id, 0])
  end
  
  def fail_count
    TestResult.count(:conditions => ["service_test_id=? AND result >= ?", self.id, 1])
  end
  
  def update_success_rate!
    count = self.test_results.count
    if count == 0
      self.success_rate = 0
    else
      count = count * 1.0
      self.success_rate = (self.pass_count/count)*100
    end
    self.save
  end
  
  def update_cached_status!
    self.cached_status = self.latest_test_result.result
    begin
      self.save!
    rescue Exception => ex
      logger.error(ex.to_s)
      return false
    end
    return true
  end
  
  def name
    #return "TestScript"  if self.test.is_a?(TestScript)
    return self.test.name  if self.test.is_a?(TestScript)
    return self.test.parent.attribute.name if self.test.parent.is_a?(Annotation)
    return self.test.property if self.test.is_a?(UrlMonitor)
  end
  
  
  def result_data_points(all_data, step=6)
    data_points = []
    lower = 0
    upper = lower+step
    limit = all_data.count - 1
    upper = limit-1 if upper > limit
    
    while upper < limit do
      all_data[upper].result = results_sum(all_data[lower..upper])
      data_points <<  all_data[upper]
      lower = upper+1
      upper = lower + step
    end
    
    return data_points
  end
  
  def results_sum(results)
    results.collect{|r| r if  r.result > 0 }.compact.count
  end
  
  # Use the the last number of results, determined by
  # limit in the line graph
  def result_values(limit = 185)
    return [self].map{|s| result_data_points(s.test_results.last(limit))}
  end
  
  # the creation date of this record
  def date
    self.created_at.to_date
  end
  
  def unchecked?
    return true if self.latest_status.label.downcase =='unchecked'
    return false
  end
  
  # Helper class method to find a "testable" object
  # given the testable object class name and id 
  def self.find_testable(testable_str, testable_id)
    testable_str.constantize.find(testable_id)
  end 
  
  # Helper instance method to check whether this test is linked to a monitoring_endpoint annotation
  def is_custom_endpoint_monitor?
    parent = self.test.parent
    
    return false unless parent.class == Annotation
    
    return parent.attribute_name == "monitoring_endpoint"
  end 
  
protected
  
  
  def generate_json_with_collections(collections, make_inline=false)
    collections ||= []

    allowed = %w{ }
    
    if collections.class==String
      collections = case collections.strip.downcase
                      when "default"
                        %w{ }
                      else []
                    end
    else
      collections.each { |x| x.downcase! }
      collections.uniq!
      collections.reject! { |x| !allowed.include?(x) }
    end
    
    data = {
      "service_test" => {
        "created_at" => self.created_at.iso8601,
        "activated" => self.activated?,
        "activated_at" => self.activated? ? self.activated_at.iso8601 : nil,
        "status" => ServiceCatalographer::Api::Json.monitoring_status(self.latest_status),
        "test_type" => JSON(self.test.to_json)
      }
    }
    
    unless make_inline
      data["service_test"]["self"] = ServiceCatalographer::Api.uri_for_object(self)
      return data.to_json
    else
      data["service_test"]["resource"] = ServiceCatalographer::Api.uri_for_object(self)
      return data["service_test"].to_json
    end
  end # generate_json_with_collections
  
end
