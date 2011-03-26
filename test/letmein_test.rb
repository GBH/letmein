require 'test/unit'
require 'rails'
require 'letmein'
require 'sqlite3'

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
$stdout_orig = $stdout
$stdout = StringIO.new

class User < ActiveRecord::Base
  # example values for password info:
  #   pass: $2a$10$0MeSaaE3I7.0FQ5ZDcKPJeD1.FzqkcOZfEKNZ/DNN.w8xOwuFdBCm
  #   salt: $2a$10$0MeSaaE3I7.0FQ5ZDcKPJe
  letmein :username, :pass_crypt, :pass_salt
end

class LetMeInTest < Test::Unit::TestCase
  def setup
    ActiveRecord::Base.logger
    ActiveRecord::Schema.define(:version => 1) do
      create_table :users do |t|
        t.column :username,   :string
        t.column :pass_crypt, :string
        t.column :pass_salt,  :string
      end
    end
  end
  
  def teardown
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.drop_table(table)
    end
  end
  
  def test_configuration_defaults
    assert config = LetMeIn::Configuration.new
    assert_equal nil,             config.model
    assert_equal 'email',         config.identifier
    assert_equal 'password_hash', config.password
    assert_equal 'password_salt', config.salt
  end
  
  def test_configuration_initialization
    conf = LetMeIn.configuration
    assert_equal 'User',        conf.model
    assert_equal 'username',    conf.identifier
    assert_equal 'pass_crypt',  conf.password
    assert_equal 'pass_salt',   conf.salt
  end
  
  def test_model_password_saving
    user = User.new(:username => 'test', :password => 'test')
    user.save!
    user = User.find(user.id)
    assert_equal nil, user.password
    assert_match /.{60}/, user.pass_crypt
    assert_match /.{29}/, user.pass_salt
  end
  
  def test_session_initialization
    session = LetMeIn::Session.new(:username => 'test_user', :password => 'test_pass')
    assert_equal 'test_user', session.identifier
    assert_equal 'test_user', session.username
    assert_equal 'test_pass', session.password
    
    session.username = 'new_user'
    assert_equal 'new_user', session.identifier
    assert_equal 'new_user', session.username
    
    assert_equal nil, session.authenticated_object
    assert_equal nil, session.user
  end
  
  def test_session_authentication
    user = User.create!(:username => 'test', :password => 'test')
    session = LetMeIn::Session.create(:username => 'test', :password => 'test')
    assert session.errors.blank?
    assert_equal user, session.authenticated_object
    assert_equal user, session.user
  end
  
  def test_session_authentication_failure
    user = User.create!(:username => 'test', :password => 'test')
    session = LetMeIn::Session.create(:username => 'test', :password => 'bad_pass')
    assert session.errors.present?
    assert_equal 'Failed to authenticate', session.errors[:base].first
    assert_equal nil, session.authenticated_object
    assert_equal nil, session.user
  end
  
  def test_session_authentication_exception
    user = User.create!(:username => 'test', :password => 'test')
    session = LetMeIn::Session.new(:username => 'test', :password => 'bad_pass')
    begin
      session.save!
    rescue LetMeIn::Error => e
      assert_equal 'Failed to authenticate', e.to_s
    end
    assert_equal nil, session.authenticated_object
  end
end