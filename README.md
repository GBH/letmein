letmein
=======

**letmein** is a minimalistic authentication plugin for Rails applications. It doesn't have anything other than the LetMeIn::Session object that you can use to authenticate logins.

Setup
=====
Assuming the model you want to authenticate has fields: *email*, *password_hash* and *password_salt* all you need to add for that model is this:
    
    class User < ActiveRecord::Base
      letmein
    end
    
If you want to use *username* instead of *email* and if maybe you prefer naming from password and salt columns to something else do this:
    
    class User < ActiveRecord::Base
      letmein :username, :encrypted_password, :salt
    end
    
When creating/updating a user record you have access to *password* accessor.
    
    >> user = User.new(:email => 'example@example.com', :password => 'letmein')
    >> user.save!
    >> user.password_hash 
    => $2a$10$0MeSaaE3I7.0FQ5ZDcKPJeD1.FzqkcOZfEKNZ/DNN.w8xOwuFdBCm
    >> user.password_salt
    => $2a$10$0MeSaaE3I7.0FQ5ZDcKPJe
    
Authentication
==============

You authenticate using LetMeIn::Session object. Example:
    
    >> session = LetMeIn::Session.new(:email => 'example@example.com', :password => 'letmein')
    >> session.save
    => true
    >> session.user
    => #<User id: 1, email: "example@example.com" ... >
    
When credentials are invalid:
    
    >> session = LetMeIn::Session.new(:email => 'example@example.com', :password => 'bad_password')
    >> session.save
    => false
    >> session.user
    => nil
    
Usage
=====
There are no built-in routes/controllers/views/helpers or anything. I'm confident you can do those yourself, because you're awesome. But here's an example how you can implement the controller handling the login:

    class SessionsController < ApplicationController
      def create
        @session = LetMeIn::Session.new(params)
        @session.save!
        session[:user_id] = @session.user.id
        flash[:notice] = "Welcome back #{@session.user.name}!"
        redirect_to '/'
      rescue LetMeIn::Error
        flash.now[:error] = 'Invalid Credentials'
        render :action => :new
      end
    end
    
Upon successful login you have access to *session[:user_id]*. The rest is up to you.

Copyright
=========
(c) 2011 Oleg Khabarov, released under the MIT license


    