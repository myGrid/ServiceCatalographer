%w{ models controllers helpers }.each do |dir|
  path = File.join(File.dirname(__FILE__), 'app', dir)
  $LOAD_PATH << path
  ActiveSupport::Dependencies.load_paths << path
  ActiveSupport::Dependencies.load_once_paths.delete(path)
end

require "#{File.dirname(__FILE__)}/annotations/acts_as_annotatable"
ActiveRecord::Base.send(:include, Annotations::Acts::Annotatable)

require "#{File.dirname(__FILE__)}/annotations/acts_as_annotation_source"
ActiveRecord::Base.send(:include, Annotations::Acts::AnnotationSource)

require "#{File.dirname(__FILE__)}/routing"