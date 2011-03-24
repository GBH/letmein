require 'active_record'

module LetMeIn
  
  require File.expand_path('letmein/configuration', File.dirname(__FILE__))
  
  def self.configuration
    @configuration ||= LetMeIn::Configuration.new
  end
  
  module Model
    def self.included(base)
      base.extend ClassMethods
    end
    
    module ClassMethods
      def letmein(*args)
        LetMeIn.configuration.model       = self.to_s
        LetMeIn.configuration.identifier  = args[0].to_s if args[0]
        LetMeIn.configuration.password    = args[1].to_s if args[1]
        LetMeIn.configuration.salt        = args[2].to_s if args[2]
      end
    end
  end
end

ActiveRecord::Base.send :include, LetMeIn::Model