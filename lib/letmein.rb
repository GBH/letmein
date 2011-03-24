module LetMeIn
  
  require File.expand_path('letmein/configuration', File.dirname(__FILE__))
  
  class << self
    # Modify LetMeIn configuration
    # Example:
    #   LetMeIn.configure do |config|
    #     config.model = 'Account'
    #   end
    def configure
      yield configuration
    end
    
    # Accessor for LetMeIn::Configuration
    def configuration
      @configuration ||= LetMeIn::Configuration.new
    end
    alias :config :configuration
  end
end