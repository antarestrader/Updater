require "rubygems"

require 'dm-core'
require 'dm-types'

class Updater
  VERSION = '0.1.0'

  include DataMapper::Resource
  
  property :id, Serial
  property :target, Class
  property :ident, Object
  property :method, String
  property :finder, String
  property :args, Object
  property :time, Integer
  
  def target
    return @target if @ident.nil?
    @target.send(@finder||:get, @ident)
  end
  
  def run
    t = target #do not trap errors here
    begin
      t.send(@method.to_sym,*@args)
    rescue => e
      false
    end
    true
  end
  
  class << self
    def at(time,target,method,args,options={})
      hash = {:method=>method.to_s,:args=>args}
      hash[:target] = target_for(target)
      hash[:ident] = ident_for(target,options[:finder],options[:finder_args])
      hash[:finder] = options[:finder] || :get
      hash[:time] = time
      create(hash)
    end
    
    def immidiate(*args)
      at(time.now,*args)
    end
    
    def time
      @@time ||= Time
    end
    
    def time=(klass)
      @@time = klass
    end
    
    def current
      all(:time.lte=>time.now.to_i)
    end
    
    def delayed
      all(:time.gt=>time.now.to_i)
    end
    
  private
    
    def target_for(inst)
      return inst if inst.kind_of? Class
      inst.class
    end
    
    def ident_for(target,finder,args)
      if !(target.kind_of?(Class)) || finder
        return target.id unless finder
        args
      end
      #Otherwize the target is the class and ident should be nil
    end
  
  end
  
end
