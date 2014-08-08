# ServiceCatalographer: lib/service_catalographer/jobs/post_tweet
#
# Copyright (c) 2009, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

module ServiceCatalographer
  module Jobs
    class PostTweet < Struct.new(:message)
      def perform
        ServiceCatalographer::Util.say "I AM TWEETING! Message: #{message}"
        ServiceCatalographer::Twittering.post_tweet(message)
      end    
    end
  end
end