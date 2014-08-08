# ServiceCatalographer: app/models/test_script.rb
#
# Copyright (c) 2009-2010, University of Manchester, The European Bioinformatics
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# requires the ContentBlob model to store the
# binary data of the uploaded test file

class TestScript < ActiveRecord::Base
  if ENABLE_CACHE_MONEY
    is_cached :repository => $cache
    index :name
    index :exec_name
  end

  has_one :service_test, 
          :as => :test, 
          :dependent => :destroy
  
  belongs_to :content_blob, 
             :dependent => :destroy
             
  acts_as_annotatable :name_field => :name
  
  has_submitter
  
  # Validations
  validates_presence_of :name, 
                        :exec_name,
                        :description,
                        :filename, 
                        :content_type,
                        :submitter_id,
#                        :content_blob_id,
                        :prog_language
                        
  validates_associated :content_blob, :message => " is invalid. Maybe the uploaded file is empty" 
  
  validates_inclusion_of :prog_language, 
                         :in  => %w[perl python java ruby utopia rest soapui], 
                         :message => " may not have been selected. Please check that you selected one of : perl, python, ruby or soupui projects(xml)"
  
  validates_inclusion_of :content_type,
                          :in => ['application/zip','application/x-zip', 'application/x-zip-compressed', 'application/xml', 
                          'text/x-python-script', 'text/x-perl-script', 'text/x-ruby-script', 'application/x-ruby', 'text/plain'],
                          :message => " is not allowed. Allowed file types are zip, xml, python, perl, and ruby"
  attr_protected :filename, 
                 :content_type
  
  if USE_EVENT_LOG
    acts_as_activity_logged(:models => { :culprit => { :model => :submitter } })
  end        

  def to_json
    {
      "test_script" => {
        "name" => self.name,
        "description" => self.description,
        "content_type" => self.content_type,
        "programming_language" => self.prog_language,
        "executable_filename" => self.exec_name,
        "download" => URI.parse(ServiceCatalographer::Api.uri_for_object(self).to_s.gsub(/\/$/, '') + "/download"),
        "submitter" => ServiceCatalographer::Api.uri_for_object(self.submitter),
        "created_at" => self.created_at.iso8601,
        "activated_at" => (self.activated_at ? self.activated_at.iso8601 : nil)
      }
    }.to_json
  end 

  # Helper class method to lookup all tests assigned
  # to all testable types for a given user.
  def self.find_tests_by_user(user)
    # Old Rails 2 style
    #find(:all,
    #  :conditions => ["submitter_id = ?", user.id],
    #  :order => "created_at DESC"
    #)
    where(:submitter_id => user.id).order("created_at DESC")
  end
  
  # Create an entry into the content_blobs table
  # containing the binary data of the uploaded file
  def test_data=(incoming_file)
    begin
      incoming_file.rewind
      self.filename     = incoming_file.original_filename
      self.content_type = incoming_file.content_type
      ServiceCatalographer::Util.say "*****"
      ServiceCatalographer::Util.say "incoming_file.content_type = #{incoming_file.content_type}"
      ServiceCatalographer::Util.say "*****"
      self.content_blob = ContentBlob.new({:data => incoming_file.read})
    rescue Exception => ex
      errors.add_to_base("Error uploading file: #{ex.backtrace.join("\n")}")
    end
  end
  
  def latest_test_result
    self.service_test.latest_test_result
  end
  
  def recent_test_results(limit=5)
    self.service_test.recent_test_results(limit)
  end

  def activated?
    self.service_test.activated?
  end
  
  def activated_at
    self.service_test.activated_at
  end

#  def filename=(new_filename)
#    write_attribute("filename", sanitize_filename(new_filename))
#  end
# 
#  private
#  def sanitize_filename(filename)
#    #get only the filename, not the whole path (from IE)
#    just_filename = File.basename(filename)
#    #replace all non-alphanumeric, underscore or periods with underscores
#    just_filename.gsub(/[^\w\.\-]/, '_')
#  end

end