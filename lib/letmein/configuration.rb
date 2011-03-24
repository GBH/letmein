class LetMeIn::Configuration
  
  # Model that is being used for authentication
  # Generally it's User, or maybe an Account
  attr_accessor :model
  
  # Unique udentifier accessor of the model. Default is set to 'email'
  attr_accessor :identifier
  
  # Password accessor of the model. Default is 'password_hash'
  attr_accessor :password
  
  # Salt accessor of the model. Default is 'password_salt'
  attr_accessor :salt
  
  # Configuration defaults
  def initialize
    @model      = 'User'
    @identifier = 'email'
    @password   = 'password_hash'
    @salt       = 'password_salt'
  end
  
end