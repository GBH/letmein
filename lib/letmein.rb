require 'active_record'
require 'bcrypt'

module LetMeIn
  
  class Error < StandardError
  end
  
  class Configuration
    attr_accessor :model, :identifier, :password, :salt
    
    def initialize
      @model      = nil
      @identifier = 'email'
      @password   = 'password_hash'
      @salt       = 'password_salt'
    end
  end
  
  class Session
    include ActiveModel::Validations
    attr_accessor :identifier, :password, :authenticated_object
    validate :authenticate
    
    def initialize(params = {})
      self.identifier = params[:identifier] || params[LetMeIn.configuration.identifier.to_sym]
      self.password   = params[:password]
    end
    
    def save
      self.valid?
    end
    
    def save!
      save || raise(LetMeIn::Error, 'Failed to authenticate')
    end
    
    def self.create(params = {})
      object = self.new(params)
      object.save
      object
    end
    
    def self.create!(params = {})
      object = self.new(params)
      object.save!
      object
    end
    
    # Mapping to the identifier and authenticated object accessor
    def method_missing(method_name, *args)
      case method_name.to_s
      when LetMeIn.configuration.identifier
        self.identifier
      when "#{LetMeIn.configuration.identifier}="
        self.identifier = args[0]
      when LetMeIn.configuration.model.underscore
        self.authenticated_object
      else
        super
      end
    end
    
    def authenticate
      object = LetMeIn.configuration.model.constantize.send("find_by_#{LetMeIn.configuration.identifier}", self.identifier)
      self.authenticated_object = if object && object.send(LetMeIn.configuration.password) == BCrypt::Engine.hash_secret(self.password, object.send(LetMeIn.configuration.salt))
        object
      else
        errors.add(:base, 'Failed to authenticate')
        nil
      end
    end
    
    def to_key
      nil
    end
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
        
        attr_accessor :password
        
        before_save :encrypt_password
        
        class_eval %Q^
          def encrypt_password
            if password.present?
              self.send("#{LetMeIn.configuration.salt}=", BCrypt::Engine.generate_salt)
              self.send("#{LetMeIn.configuration.password}=", BCrypt::Engine.hash_secret(password, self.send(LetMeIn.configuration.salt)))
            end
          end
        ^
      end
    end
  end
  
  def self.configuration
    @configuration ||= LetMeIn::Configuration.new
  end
end

ActiveRecord::Base.send :include, LetMeIn::Model

# Rails loads models on demand. Configuration doesn't set properly unless assosiated model
# is already loaded. This will force it.
Dir[Rails.root + 'app/models/**/*.rb'].each{|path| require path }
