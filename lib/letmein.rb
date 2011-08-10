require 'active_record'
require 'bcrypt'

module LetMeIn
  
  Error = Class.new StandardError
  
  class Railtie < Rails::Railtie
    config.to_prepare do
      LetMeIn.initialize
    end
  end
  
  # Configuration class with some defaults. Can be changed like this:
  #   LetMeIn.configure do |conf|
  #     conf.model      = 'Account'
  #     conf.identifier = 'username'
  #   end
  class Config
    ACCESSORS = %w(models identifiers passwords salts)
    attr_accessor *ACCESSORS
    def initialize
      @models       = ['User']
      @identifiers  = ['email']
      @passwords    = ['password_hash']
      @salts        = ['password_salt']
    end
    ACCESSORS.each do |a|
      define_method("#{a.singularize}=") do |val|
        send("#{a}=", [val].flatten)
      end
    end
  end
  
  def self.config
    @config ||= Config.new
  end
  
  def self.configure
    yield config
  end
  
  def self.initialize
    
    def self.accessor(name, index = 0)
      name = name.to_s.pluralize
      self.config.send(name)[index] || self.config.send(name)[0]
    end
    
    self.config.models.each do |model|
      klass = model.constantize rescue next
      
      klass.send :include, LetMeIn::Model
      
      Object.const_set("#{model.to_s.camelize}Session", Class.new do
        include ActiveModel::Validations
        attr_accessor :identifier, :password, :authenticated_object
        validate :authenticate
        
        def initialize(params = { })
          unless params.blank?
            i = LetMeIn.accessor(:identifier, LetMeIn.config.models.index(self.class.to_s.gsub('Session','')))
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
          i = LetMeIn.accessor(:identifier, LetMeIn.config.models.index(m))
          case method_name.to_s
            when i            then self.identifier
            when "#{i}="      then self.identifier = args[0]
            when m.underscore then self.authenticated_object
            else super
          end
        end
        
        def authenticate
          m = self.class.to_s.gsub('Session','')
          i = LetMeIn.accessor(:identifier, LetMeIn.config.models.index(m))
          p = LetMeIn.accessor(:password, LetMeIn.config.models.index(m))
          s = LetMeIn.accessor(:password, LetMeIn.config.models.index(m))
          object = m.constantize.send("find_by_#{i}", self.identifier)
          self.authenticated_object = if object && !object.send(p).blank? && object.send(p) == BCrypt::Engine.hash_secret(self.password, object.send(s))
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
            p = LetMeIn.accessor(:password, LetMeIn.config.models.index(self.class.to_s))
            s = LetMeIn.accessor(:salt, LetMeIn.config.models.index(self.class.to_s))
            self.send("#{s}=", BCrypt::Engine.generate_salt)
            self.send("#{p}=", BCrypt::Engine.hash_secret(password, self.send(s)))
          end
        end
      end
    end
  end
end