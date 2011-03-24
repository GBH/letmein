require 'test/unit'
require 'active_record'
require 'letmein'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
$stdout_orig = $stdout
$stdout = StringIO.new

class User < ActiveRecord::Base
  letmein :name, :pass_crypt, :pass_salt
end

class LetMeInTest < Test::Unit::TestCase
  def setup
    ActiveRecord::Base.logger
    ActiveRecord::Schema.define(:version => 1) do
      create_table :users do |t|
        t.column :name,       :string
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
  
  # -- Tests ----------------------------------------------------------------
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
    assert_equal 'name',        conf.identifier
    assert_equal 'pass_crypt',  conf.password
    assert_equal 'pass_salt',   conf.salt
  end
end