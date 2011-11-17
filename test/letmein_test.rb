require 'test/unit'
require 'rails'
require 'letmein'
require 'sqlite3'

$stdout_orig = $stdout
$stdout = StringIO.new
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
ActiveRecord::Base.logger = Logger.new($stdout)

class User  < ActiveRecord::Base ; end
class Admin < ActiveRecord::Base ; end

class OpenSession < LetMeIn::Session
  # @model, @attribute = 'User', 'email'
  def authenticate
    super
  end
end

class ClosedSession < LetMeIn::Session
  # @model, @attribute = 'User', 'email'
  def authenticate
    super
    errors.add :base, "You shall not pass #{user.email}"
  end
end

class CustomAdminSession < LetMeIn::Session
  @model = 'Admin'
  # ...
end

class LetMeInTest < Test::Unit::TestCase
  
  def setup
    ActiveRecord::Base.logger
    ActiveRecord::Schema.define(:version => 1) do
      create_table :users do |t|
        t.column :email,          :string
        t.column :password_hash,  :string
        t.column :password_salt,  :string
        t.column :auth_token,     :string
      end
      create_table :admins do |t|
        t.column :username,   :string
        t.column :pass_hash,  :string
        t.column :pass_salt,  :string
        t.column :token_auth, :string
      end
    end
    init_default_configuration
  end
  
  def init_default_configuration
    remove_session_classes
    LetMeIn.configure do |c|
      c.models          = ['User']
      c.attributes      = ['email']
      c.passwords       = ['password_hash']
      c.salts           = ['password_salt']
      c.tokens          = ['auth_token']
      c.generate_tokens = [false]
    end
    LetMeIn.initialize
  end
  
  def init_custom_configuration
    remove_session_classes
    LetMeIn.configure do |c|
      c.models          = ['User', 'Admin']
      c.attributes      = ['email', 'username']
      c.passwords       = ['password_hash', 'pass_hash']
      c.salts           = ['password_salt', 'pass_salt']
      c.tokens          = ['auth_token', 'token_auth']
      c.generate_tokens = [false, true]
    end
    LetMeIn.initialize
  end

  def remove_session_classes
    Object.send(:remove_const, :UserSession)  rescue nil
    Object.send(:remove_const, :AdminSession) rescue nil
  end
  
  def teardown
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.drop_table(table)
    end
    remove_session_classes
  end
  
  # -- Tests ----------------------------------------------------------------
  def test_default_configuration_initialization
    assert_equal ['User'],          LetMeIn.config.models
    assert_equal ['email'],         LetMeIn.config.attributes
    assert_equal ['password_hash'], LetMeIn.config.passwords
    assert_equal ['password_salt'], LetMeIn.config.salts
    assert_equal ['auth_token'],    LetMeIn.config.tokens
  end
  
  def test_custom_configuration_initialization
    LetMeIn.configure do |c|
      c.model       = 'Account'
      c.attribute   = 'username'
      c.password    = 'encrypted_pass'
      c.salt        = 'salt'
      c.token       = 'token_auth'
    end
    assert_equal ['Account'],         LetMeIn.config.models
    assert_equal ['username'],        LetMeIn.config.attributes
    assert_equal ['encrypted_pass'],  LetMeIn.config.passwords
    assert_equal ['salt'],            LetMeIn.config.salts
    assert_equal ['token_auth'],      LetMeIn.config.tokens
  end
  
  def test_model_integration
    assert User.new.respond_to?(:password)
    user = User.create!(:email => 'test@test.test', :password => 'pass')
    assert_match /^.{60}$/, user.password_hash
    assert_match /^.{29}$/, user.password_salt
  end
  
  def test_model_integration_custom
    init_custom_configuration
    assert Admin.new.respond_to?(:password)
    user = Admin.create!(:username => 'test', :password => 'pass')
    assert_match /^.{60}$/, user.pass_hash
    assert_match /^.{29}$/, user.pass_salt
  end
  
  def test_session_initialization
    assert defined?(UserSession)
    session = UserSession.new(:email => 'test@test.test', :password => 'pass')
    assert_equal 'test@test.test', session.login
    assert_equal 'test@test.test', session.email
    assert_equal 'pass', session.password
    
    session.email = 'new_user@test.test'
    assert_equal 'new_user@test.test', session.login
    assert_equal 'new_user@test.test', session.email
    
    assert_equal nil, session.object
    assert_equal nil, session.user
  end
  
  def test_session_initialization_secondary
    init_custom_configuration
    assert defined?(AdminSession)
    session = AdminSession.new(:username => 'admin', :password => 'test_pass')
    assert_equal 'admin', session.login
    assert_equal 'admin', session.username
    assert_equal 'test_pass', session.password
    
    session.username = 'new_admin'
    assert_equal 'new_admin', session.login
    assert_equal 'new_admin', session.username
    
    assert_equal nil, session.object
    assert_equal nil, session.admin
  end
  
  def test_session_authentication
    user = User.create!(:email => 'test@test.test', :password => 'pass')
    session = UserSession.create(:email => user.email, :password => 'pass')
    assert session.errors.blank?
    assert_equal user, session.object
    assert_equal user, session.user
  end
  
  def test_session_authentication_custom
    init_custom_configuration
    admin = Admin.create!(:username => 'admin', :password => 'pass')
    session = AdminSession.create(:username => admin.username, :password => 'pass')
    assert session.errors.blank?
    assert_equal admin, session.object
    assert_equal admin, session.admin
  end
  
  def test_session_authentication_failure
    user = User.create!(:email => 'test@test.test', :password => 'pass')
    session = UserSession.create(:email => user.email, :password => 'bad_pass')
    assert session.errors.present?
    assert_equal 'Failed to authenticate', session.errors[:base].first
    assert_equal nil, session.object
    assert_equal nil, session.user
  end
  
  def test_session_authentication_exception
    user = User.create!(:email => 'test@test.test', :password => 'pass')
    session = UserSession.new(:email => user.email, :password => 'bad_pass')
    begin
      session.save!
    rescue LetMeIn::Error => e
      assert_equal 'Failed to authenticate', e.to_s
    end
    assert_equal nil, session.object
  end
  
  def test_session_authentication_on_blank_object
    user = User.create!(:email => 'test@test.test')
    session = UserSession.new(:email => 'test@test.test', :password => 'pass')
    begin
      session.save!
    rescue LetMeIn::Error => e
      assert_equal 'Failed to authenticate', e.to_s
    end
    assert_equal nil, session.object
  end
  
  def test_custom_open_session
    user = User.create!(:email => 'test@test.test', :password => 'pass')
    session = OpenSession.new(:email => 'test@test.test', :password => 'bad_pass')
    assert session.invalid?
    assert_equal 'Failed to authenticate', session.errors[:base].first
    session = OpenSession.new(:email => 'test@test.test', :password => 'pass')
    assert session.valid?
    assert_equal user, session.user
  end
  
  def test_custom_closed_session
    user = User.create!(:email => 'test@test.test', :password => 'pass')
    session = ClosedSession.new(:email => 'test@test.test', :password => 'pass')
    assert session.invalid?
    assert_equal 'You shall not pass test@test.test', session.errors[:base].first
  end
  
  def test_custom_admin_session
    init_custom_configuration
    admin = Admin.create!(:username => 'admin', :password => 'pass')
    session = CustomAdminSession.new(:username => 'admin', :password => 'pass')
    assert session.valid?
    assert_equal admin, session.admin
  end

  # Token Authentication Related

  def test_generate_token_false_by_default
    init_default_configuration
    user = User.create!(:email => 'test@test.test', :password => 'pass')
    assert_equal [false], LetMeIn.config.generate_tokens
    assert_nil user.auth_token
  end

  def test_generate_token
    init_custom_configuration
    admin = Admin.create!(:username => 'admin', :password => 'pass')
    assert_match /^.{40}$/, admin.token_auth
  end

  def test_token_session_init
    init_custom_configuration
    session = AdminSession.new(:token_auth => "29dkd38kduhuf88wldke21")
    assert_equal "29dkd38kduhuf88wldke21", session.token
    assert_nil session.object
    assert_nil session.admin
  end

  def test_ignore_token_session_init
    init_default_configuration
    session = UserSession.new(:auth_token => "29dkd38kduhuf88wldke21")
    assert_nil session.token
    assert_nil session.object
    assert_nil session.user
  end

  def test_token_authentication
    init_custom_configuration
    admin = Admin.create!(:username => 'admin', :password => 'pass')
    session = AdminSession.create(:token_auth => admin.token_auth)
    assert session.errors.blank?
    assert_equal admin, session.object
    assert_equal admin, session.admin
  end

  def test_token_authentication_failure
    init_custom_configuration
    admin = Admin.create!(:username => 'admin', :password => 'pass')
    session = AdminSession.create(:token_auth => 'bad_token')
    assert session.errors.present?
    assert_equal 'Failed to authenticate', session.errors[:base].first
    assert_nil session.object
    assert_nil session.admin
  end

  def test_token_authentication_exception
    init_custom_configuration
    admin = Admin.create!(:username => 'admin', :password => 'pass')
    session = AdminSession.new(:token_auth => 'bad_token')
    begin
      session.save!
    rescue LetMeIn::Error => e
      assert_equal 'Failed to authenticate', e.to_s
    end
    assert_nil session.object
    assert_nil session.admin
  end

end