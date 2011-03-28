require 'test/unit'
require 'rails'
require 'letmein'
require 'sqlite3'

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
$stdout_orig = $stdout
$stdout = StringIO.new

class User  < ActiveRecord::Base ; end
class Admin < ActiveRecord::Base ; end

class LetMeInTest < Test::Unit::TestCase
  def setup
    ActiveRecord::Base.logger
    ActiveRecord::Schema.define(:version => 1) do
      create_table :users do |t|
        t.column :email,          :string
        t.column :password_hash,  :string
        t.column :password_salt,  :string
      end
      create_table :admins do |t|
        t.column :username,   :string
        t.column :pass_hash,  :string
        t.column :pass_salt,  :string
      end
    end
    LetMeIn.initialize(
      :model      => ['User', 'Admin'],
      :identifier => ['email', 'username'],
      :password   => ['password_hash', 'pass_hash'],
      :salt       => ['password_salt', 'pass_salt']
    )
    User.create!(:email => 'test@test.test', :password => 'test')
    Admin.create!(:username => 'admin', :password => 'test')
  end
  
  def teardown
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.drop_table(table)
    end
    Object.send(:remove_const, :UserSession)
    Object.send(:remove_const, :AdminSession)
  end
  
  def test_configuration_initialization
    assert_equal ['User', 'Admin'],               LetMeIn.models
    assert_equal ['email', 'username'],           LetMeIn.identifiers
    assert_equal ['password_hash', 'pass_hash'],  LetMeIn.passwords
    assert_equal ['password_salt', 'pass_salt'],  LetMeIn.salts
  end
  
  def test_model_password_saving
    user = User.first
    assert_equal nil, user.password
    assert_match /.{60}/, user.password_hash
    assert_match /.{29}/, user.password_salt
  end
  
  def test_model_password_saving_secondary
    user = Admin.first
    assert_equal nil, user.password
    assert_match /.{60}/, user.pass_hash
    assert_match /.{29}/, user.pass_salt
  end
  
  def test_session_initialization
    session = UserSession.new(:email => 'test@test.test', :password => 'test_pass')
    assert_equal 'test@test.test', session.identifier
    assert_equal 'test@test.test', session.email
    assert_equal 'test_pass', session.password
    
    session.email = 'new_user@test.test'
    assert_equal 'new_user@test.test', session.identifier
    assert_equal 'new_user@test.test', session.email
    
    assert_equal nil, session.authenticated_object
    assert_equal nil, session.user
  end
  
  def test_session_initialization_secondary
    session = AdminSession.new(:username => 'admin', :password => 'test_pass')
    assert_equal 'admin', session.identifier
    assert_equal 'admin', session.username
    assert_equal 'test_pass', session.password
    
    session.username = 'new_admin'
    assert_equal 'new_admin', session.identifier
    assert_equal 'new_admin', session.username
    
    assert_equal nil, session.authenticated_object
    assert_equal nil, session.admin
  end
  
  def test_session_authentication
    session = UserSession.create(:email => User.first.email, :password => 'test')
    assert session.errors.blank?
    assert_equal User.first, session.authenticated_object
    assert_equal User.first, session.user
  end
  
  def test_session_authentication_secondary
    session = AdminSession.create(:username => Admin.first.username, :password => 'test')
    assert session.errors.blank?
    assert_equal Admin.first, session.authenticated_object
    assert_equal Admin.first, session.admin
  end
  
  def test_session_authentication_failure
    session = UserSession.create(:email => User.first.email, :password => 'bad_pass')
    assert session.errors.present?
    assert_equal 'Failed to authenticate', session.errors[:base].first
    assert_equal nil, session.authenticated_object
    assert_equal nil, session.user
  end
  
  def test_session_authentication_exception
    session = UserSession.new(:email => User.first.email, :password => 'bad_pass')
    begin
      session.save!
    rescue LetMeIn::Error => e
      assert_equal 'Failed to authenticate', e.to_s
    end
    assert_equal nil, session.authenticated_object
  end
end