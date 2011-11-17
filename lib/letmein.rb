require 'active_record'
require 'active_support/secure_random'
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
    ACCESSORS = %w(models attributes passwords salts tokens generate_tokens)
    attr_accessor *ACCESSORS
    def initialize
      @models           = ['User']
      @attributes       = ['email']
      @passwords        = ['password_hash']
      @salts            = ['password_salt']
      @tokens           = ['auth_token']
      @generate_tokens  = [false]
    end
    ACCESSORS.each do |a|
      define_method("#{a.singularize}=") do |val|
        send("#{a}=", [val].flatten)
      end
    end
  end
  
  # LetMeIn::Session object. Things like UserSession are created
  # automatically after the initialization
  class Session
    
    # class MySession < LetMeIn::Session
    #   @model      = 'User'
    #   @attribute  = 'email'
    # end
    class << self
      attr_accessor :model, :attribute
    end
    
    include ActiveModel::Validations
    
    attr_accessor :login,       # test@test.test
                  :password,    # secretpassword
                  :token,       # 40 char, hex, single token authentication
                  :object       # authenticated object
                  
    validate :authenticate
    
    def initialize(params = { })
      model = self.class.to_s.gsub('Session', '')
      model = LetMeIn.config.models.member?(model) ? model : LetMeIn.config.models.first
      self.class.model      ||= model
      self.class.attribute  ||= LetMeIn.accessor(:attribute, LetMeIn.config.models.index(self.class.model))
      self.login      = params[:login] || params[self.class.attribute.to_sym]
      self.password   = params[:password]
      self.token      = params[self.token_attribute.to_sym] if allow_tokens?
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
      case method_name.to_s
        when self.class.attribute         then self.login
        when "#{self.class.attribute}="   then self.login = args[0]
        when self.class.model.underscore  then self.object
        else super
      end
    end
    
    def authenticate
      unless self.token
        p = LetMeIn.accessor(:password, LetMeIn.config.models.index(self.class.model))
        s = LetMeIn.accessor(:salt, LetMeIn.config.models.index(self.class.model))
        
        object = self.class.model.constantize.where(self.class.attribute => self.login).first
        self.object = object if object && !object.send(p).blank? && object.send(p) == BCrypt::Engine.hash_secret(self.password, object.send(s))
      else
        self.object = self.class.model.constantize.where(self.token_attribute => self.token).first
      end
      
      if self.object
        self.token = self.object.send(self.token_attribute) if allow_tokens?
        object
      else
        errors.add :base, 'Failed to authenticate'
        nil
      end
    end
    
    def to_key
      nil
    end

    protected

      def token_attribute
        LetMeIn.accessor(:token, LetMeIn.config.models.index(self.class.model))
      end

      def allow_tokens?
        LetMeIn.config.generate_tokens[LetMeIn.config.models.index(self.class.model)] ? true : false
      end

  end
  
  module Model
    def self.included(base)
      base.instance_eval do
        attr_accessor :password
        before_save :encrypt_password
        before_save :generate_token
        
        define_method :encrypt_password do
          if password.present?
            p = LetMeIn.accessor(:password, LetMeIn.config.models.index(self.class.to_s))
            s = LetMeIn.accessor(:salt, LetMeIn.config.models.index(self.class.to_s))
            self.send("#{s}=", BCrypt::Engine.generate_salt)
            self.send("#{p}=", BCrypt::Engine.hash_secret(password, self.send(s)))
          end
        end

        define_method :generate_token do
          i = LetMeIn.config.models.index(self.class.to_s)
          if LetMeIn.config.generate_tokens[i]
            t = LetMeIn.accessor(:token, i)
            token = nil
            loop do
              token = SecureRandom.hex(20)
              break token unless base.where(t => token).exists?
            end
            self.send("#{t}=", token)
          end
        end
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
      
      session_model = "#{model.to_s.camelize}Session"
      
      # remove the constant if it's defined, so that we don't get spammed with warnings.
      Object.send(:remove_const, session_model) if (Object.const_get(session_model) rescue nil) 
      Object.const_set(session_model, Class.new(LetMeIn::Session))
    end
  end
end