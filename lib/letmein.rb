require 'active_record'
require 'bcrypt'

module LetMeIn
  
  Error = Class.new StandardError
  
  class Railtie < Rails::Railtie
    config.after_initialize do
      LetMeIn.initialize unless LetMeIn.models.present?
    end
  end
  
  mattr_accessor :models, :identifiers, :passwords, :salts
  def self.initialize(params = {})
    @@models      = [params[:model]      || 'User'          ].flatten
    @@identifiers = [params[:identifier] || 'email'         ].flatten
    @@passwords   = [params[:password]   || 'password_hash' ].flatten
    @@salts       = [params[:salt]       || 'password_salt' ].flatten
    
    def self.accessor(name, index = 0)
      name = name.to_s.pluralize
      self.send(name)[index] || self.send(name)[0]
    end
    
    @@models.each do |model|
      
      model.constantize.send :include, LetMeIn::Model
      
      Object.const_set("#{model.to_s.camelize}Session", Class.new do
        include ActiveModel::Validations
        attr_accessor :identifier, :password, :authenticated_object
        validate :authenticate
        
        def initialize(params = { })
          unless params.blank?
            i = LetMeIn.accessor(:identifier, LetMeIn.models.index(self.class.to_s.gsub('Session','')))
            self.identifier = params[:identifier] || params[i.to_sym]
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
          object = self.new(params); object.save; object
        end
        
        def self.create!(params = {})
          object = self.new(params); object.save!; object
        end
        
        def method_missing(method_name, *args)
          m = self.class.to_s.gsub('Session','')
          i = LetMeIn.accessor(:identifier, LetMeIn.models.index(m))
          case method_name.to_s
            when i            then self.identifier
            when "#{i}="      then self.identifier = args[0]
            when m.underscore then self.authenticated_object
            else super
          end
        end
        
        def authenticate
          m = self.class.to_s.gsub('Session','')
          i = LetMeIn.accessor(:identifier, LetMeIn.models.index(m))
          p = LetMeIn.accessor(:password, LetMeIn.models.index(m))
          s = LetMeIn.accessor(:password, LetMeIn.models.index(m))
          object = m.constantize.send("find_by_#{i}", self.identifier)
          self.authenticated_object = if object && object.send(p) == BCrypt::Engine.hash_secret(self.password, object.send(s))
            object
          else
            errors.add :base, 'Failed to authenticate'
            nil
          end
        end
        
        def to_key
          nil
        end
      end)
    end
  end
  
  module Model
    def self.included(base)
      base.instance_eval do
        attr_accessor :password
        before_save :encrypt_password
        
        define_method :encrypt_password do
          if password.present?
            p = LetMeIn.accessor(:password, LetMeIn.models.index(self.class.to_s))
            s = LetMeIn.accessor(:salt, LetMeIn.models.index(self.class.to_s))
            self.send("#{s}=", BCrypt::Engine.generate_salt)
            self.send("#{p}=", BCrypt::Engine.hash_secret(password, self.send(s)))
          end
        end
      end
    end
  end
end