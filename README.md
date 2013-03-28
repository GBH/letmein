# letmein [![Build Status](http://travis-ci.org/GBH/letmein.png)](http://travis-ci.org/GBH/letmein)

**letmein** is a minimalistic authentication plugin for Rails 3 applications. It doesn't have anything other than the UserSession (or WhateverSession) object that you can use to authenticate logins.

Setup
=====

Plug the thing below into Gemfile and you know what to do after.

    gem 'letmein'

If you want to authenticate *User* with database fields *email*, *password_hash* and *password_salt* you don't need to do anything. If you're authenticating something else, you want something like this in your initializers:
    
    LetMeIn.configure do |conf|
      conf.model      = 'Account'
      conf.attribute  = 'username'
      conf.password   = 'password_crypt'
      conf.salt       = 'salty_salt'
    end
    
When creating/updating a record you have access to *password* accessor.
    
    >> user = User.new(:email => 'example@example.com', :password => 'letmein')
    >> user.save!
    => true
    >> user.password_hash 
    => $2a$10$0MeSaaE3I7.0FQ5ZDcKPJeD1.FzqkcOZfEKNZ/DNN.w8xOwuFdBCm
    >> user.password_salt
    => $2a$10$0MeSaaE3I7.0FQ5ZDcKPJe
    
Authentication
==============

You authenticate using UserSession object. Example:
    
    >> session = UserSession.new(:email => 'example@example.com', :password => 'letmein')
    >> session.save
    => true
    >> session.user
    => #<User id: 1, email: "example@example.com" ... >
    
When credentials are invalid:
    
    >> session = UserSession.new(:email => 'example@example.com', :password => 'bad_password')
    >> session.save
    => false
    >> session.user
    => nil
    
Usage
=====

There are no built-in routes/controllers/views/helpers or anything. I'm confident you can do those yourself, because you're awesome. But here's an example how you can implement the controller handling the login:

    class SessionsController < ApplicationController
      def create
        @session = UserSession.new(params[:user_session])
        @session.save!
        
        # Store the user in session and get a fresh session id
        session[:user_id] = @session.user.id
        request.session_options[:renew] = true
        
        flash[:notice] = "Welcome back #{@session.user.name}!"
        redirect_to '/'
        
      rescue LetMeIn::Error
        flash.now[:error] = 'Invalid Credentials'
        render :action => :new
      end
    end
    
Upon successful login you have access to *session[:user_id]*. The rest is up to you.

Authenticating Multiple Models
==============================
Yes, you can do that too. Let's assume you also want to authenticate admins that don't have email addresses, but have usernames.

    LetMeIn.configure do |conf|
      conf.models     = ['User', 'Admin']
      conf.attributes = ['email', 'username']
    end
    
Bam! You're done. Now you have an AdminSession object that will use *username* and *password* to authenticate.

Overriding Session Authentication
=================================
By default user will be logged in if provided email and password match. If you need to add a bit more logic to that you'll need to create your own session object. In the following example we do an additional check to see if user is 'approved' before letting him in.

    class MySession < LetMeIn::Session
      # Model that is being authenticated is derived from the class name
      # If you're authenticating multiple models you need to specify which one
      @model = 'User'
      
      def authenticate
        super # need to authenticate with email/password first
        unless user && user.is_approved?
          # adding a validation error will prevent login
          errors.add :base, "You are not approved yet, #{user.name}."
        end
      end
    end

Copyright
=========
(c) 2011 Oleg Khabarov, released under the MIT license
