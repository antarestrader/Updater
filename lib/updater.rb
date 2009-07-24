require "rubygems"

require 'dm-core'
require 'dm-types'

class Updater
  attr_reader :error
  VERSION = File.read(File.join(File.dirname(__FILE__),'..','VERSION')).strip

  include DataMapper::Resource
  
  property :id, Serial
  property :target, Class
  property :ident, Yaml
  property :method, String
  property :finder, String
  property :args, Object
  property :time, Integer
  property :name, String
  
  #will be called if an error occurs
  belongs_to :failure, :class_name=>'Updater', :child_key=>[:failure_id]
  
  def target
    return @target if @ident.nil?
    @target.send(@finder||:get, @ident)
  end
  
  def run
    t = target #do not trap errors here
    begin
      t.send(@method.to_sym,*@args)
    rescue => e
      @error = e
      failure.run if failure
      false
    end
    true
  end
  
  class << self
    def at(time,target,method,args,options={})
      finder, finder_args = [:finder,:finder_args].map {|key| options.delete(key)}
      hash = {:method=>method.to_s,:args=>args}
      hash[:target] = target_for(target)
      hash[:ident] = ident_for(target,finder,finder_args)
      hash[:finder] = finder || :get
      hash[:time] = time
      create(hash.merge(options))
    end
        
    def immidiate(*args)
      at(time.now,*args)
    end
    
    def chain(*args)
      at(nil,*args)
    end
    
    def for(target,name=nil)
      ident = ident_for(target)
      target = target_for(target)
      if name
        first(:target=>target,:ident=>ident,:name=>name)
      else
        all(:target=>target,:ident=>ident)
      end
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
    
    def ident_for(target,finder=nil,args=nil)
      if !(target.kind_of?(Class)) || finder
        return target.id unless finder
        args
      end
      #Otherwize the target is the class and ident should be nil
    end
  
  end
  
  
  def inspect
    "#<Updater id=#{id} target=#{target.inspect}>"
  end
end
