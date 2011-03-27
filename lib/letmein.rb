require 'active_record'
require 'bcrypt'

module LetMeIn
  
  mattr_accessor :model, :identifier, :password, :salt
  
  def self.initialize(params = {})
    @@model       = params[:model]      || 'User'
    @@identifier  = params[:identifier] || 'email'
    @@password    = params[:password]   || 'password_hash'
    @@salt        = params[:salt]       || 'password_salt'
    @@model.constantize.send :include, LetMeIn::Model
  end
  
  class Railtie < Rails::Railtie
    config.after_initialize do
      LetMeIn.initialize unless LetMeIn.model.present?
    end
  end
  
  class Error < StandardError
  end
  
  module Model
    def self.included(base)
      base.instance_eval do
        attr_accessor :password
        before_save :encrypt_password
      end
      base.class_eval do
        class_eval %Q^
          def encrypt_password
            if password.present?
              self.send("#{LetMeIn.salt}=", BCrypt::Engine.generate_salt)
              self.send("#{LetMeIn.password}=", BCrypt::Engine.hash_secret(password, self.send(LetMeIn.salt)))
            end
          end
        ^
      end
    end
  end
  
  class Session
    include ActiveModel::Validations
    attr_accessor :identifier, :password, :authenticated_object
    validate :authenticate
    
    def initialize(params = { })
      unless params.blank?
        self.identifier = params[:identifier] || params[LetMeIn.identifier.to_sym]
        self.password   = params[:password]
      end
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
        when LetMeIn.identifier       then self.identifier
        when "#{LetMeIn.identifier}=" then self.identifier = args[0]
        when LetMeIn.model.underscore then self.authenticated_object
        else super
      end
    end
    
    def authenticate
      object = LetMeIn.model.constantize.send("find_by_#{LetMeIn.identifier}", self.identifier)
      self.authenticated_object = if object && object.send(LetMeIn.password) == BCrypt::Engine.hash_secret(self.password, object.send(LetMeIn.salt))
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
end