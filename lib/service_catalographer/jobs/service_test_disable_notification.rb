# ServiceCatalographer: lib/service_catalographer/jobs/service_test_disable_notification.rb
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

module ServiceCatalographer
  module Jobs
    class ServiceTestDisableNotification < Struct.new(:user,  :service_test, :to_emails, :base_host)
      def perform
        UserMailer.service_test_disable_notification(user, service_test, to_emails, base_host).deliver
      end    
    end
  end
end