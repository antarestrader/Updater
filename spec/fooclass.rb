class Foo
  class << self
    def index
      @index ||= 0
      @index += 1
    end
    
    def create(*args)
      new(*args).tap {|r| r.save}
    end
    
    def storage
      @storage ||= {}
    end
    
    def find(id)
      storage[id]
    end
    
    alias special_foo_finder find
    
    def reset
      @storage = {}
    end
    
    def count
      storage.length
    end
    
  end
  attr_reader :id
  attr_accessor :name
  
  def bar(*args)
    Foo.bar(:instance,*args)
  end
  
  def special_foo_identification
    @id
  end
  
  def self.bar(*args) 
    
  end
  
  def initialize(hash = {})
    @id = Foo.index
    @name = hash[:name]
  end
  
  def save
    Foo.storage[self.id] = self
  end
  
end
