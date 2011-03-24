class LetMeIn::Session
  
  include ActiveModel::Validations
  
  attr_accessor :name,
                :password,
                :authenticated_object
                
  # -- Validation -----------------------------------------------------------
  validate :authenticate
  
  # -- Initialization -------------------------------------------------------
  def initialize(params = {})
    self.name     = params[:name]
    self.password = params[:password]
  end
  
  # -- Class Methods --------------------------------------------------------
  def self.create(params = {})
    self.new(params).save
  end
  
  def self.create!(params = {})
    self.new(params).save!
  end
  
  # -- Instance Methods -----------------------------------------------------
  def save
    if self.valid?
      self.authenticated_object = 'Blah'
      self
    else
      self.authenticated_object = nil
      false
    end
  end
  
  def save!
    save || raise(ResourceInvalid.new(self))
  end
  
protected
  
  def authenticate
    BCrypt::Engine.hash_secret(self.password, user.password_salt)
  end
  
end