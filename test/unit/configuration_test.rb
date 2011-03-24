require File.expand_path('../test_helper', File.dirname(__FILE__))

class ConfigurationTest < Test::Unit::TestCase
  
  def test_configuration_presense
    assert config = LetMeIn.configuration
    assert_equal 'User',          config.model
    assert_equal 'email',         config.identifier
    assert_equal 'password_hash', config.password
    assert_equal 'password_salt', config.salt
  end
  
  def test_initialization_overrides
    LetMeIn.configuration.model = 'Account'
    assert_equal 'Account', LetMeIn.configuration.model
  end
  
end