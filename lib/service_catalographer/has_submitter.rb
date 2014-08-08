# ServiceCatalographer: lib/service_catalographer/has_submitter.rb
#
# Copyright (c) 2009, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

module ServiceCatalographer
  module HasSubmitter #:nodoc:
    def self.included(mod)
      mod.extend(ClassMethods)
    end
    
    module ClassMethods
      def has_submitter
        belongs_to :submitter,
                   :polymorphic => true

        class_eval do
          extend ServiceCatalographer::HasSubmitter::SingletonMethods
        end
        include ServiceCatalographer::HasSubmitter::InstanceMethods
      end
    end
    
    module SingletonMethods
      
    end
    
    module InstanceMethods
      def submitter_name
        %w{ preferred_name display_name title name }.each do |w|
          return eval("submitter.#{w}") if submitter.respond_to?(w)
        end
        return "#{submitter.class.name}_#{submitter.id}"
      end 
    end
  end
end

ActiveRecord::Base.send(:include, ServiceCatalographer::HasSubmitter)