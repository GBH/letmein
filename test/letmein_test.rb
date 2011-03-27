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
end

class LetMeInTest < Test::Unit::TestCase
  def setup
    ActiveRecord::Base.logger
    ActiveRecord::Schema.define(:version => 1) do
      create_table :users do |t|
        t.column :email,          :string
        t.column :password_hash,  :string
        t.column :password_salt,  :string
      end
    end
    LetMeIn.initialize
    User.create!(:email => 'test@test.test', :password => 'test')
  end
  
  def teardown
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.drop_table(table)
    end
  end
  
  def test_configuration_initialization
    assert_equal 'User',          LetMeIn.model
    assert_equal 'email',         LetMeIn.identifier
    assert_equal 'password_hash', LetMeIn.password
    assert_equal 'password_salt', LetMeIn.salt
  end
  
  def test_model_password_saving
    user = User.first
    assert_equal nil, user.password
    assert_match /.{60}/, user.password_hash
    assert_match /.{29}/, user.password_salt
  end
  
  def test_session_initialization
    session = LetMeIn::Session.new(:email => 'test@test.test', :password => 'test_pass')
    assert_equal 'test@test.test', session.identifier
    assert_equal 'test@test.test', session.email
    assert_equal 'test_pass', session.password
    
    session.email = 'new_user@test.test'
    assert_equal 'new_user@test.test', session.identifier
    assert_equal 'new_user@test.test', session.email
    
    assert_equal nil, session.authenticated_object
    assert_equal nil, session.user
  end
  
  def test_session_authentication
    session = LetMeIn::Session.create(:email => User.first.email, :password => 'test')
    assert session.errors.blank?
    assert_equal User.first, session.authenticated_object
    assert_equal User.first, session.user
  end
  
  def test_session_authentication_failure
    session = LetMeIn::Session.create(:email => User.first.email, :password => 'bad_pass')
    assert session.errors.present?
    assert_equal 'Failed to authenticate', session.errors[:base].first
    assert_equal nil, session.authenticated_object
    assert_equal nil, session.user
  end
  
  def test_session_authentication_exception
    session = LetMeIn::Session.new(:email => User.first.email, :password => 'bad_pass')
    begin
      session.save!
    rescue LetMeIn::Error => e
      assert_equal 'Failed to authenticate', e.to_s
    end
    assert_equal nil, session.authenticated_object
  end
end