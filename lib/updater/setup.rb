require 'logger'
require 'yaml'
require 'socket'
require 'erb'

module Updater
  class Setup
    class << self
      def start
        new(config_file).start
      end
      
      def stop
        new(config_file).stop
      end
      
      def monitor
        
      end
          
      def config_file
        if ENV['UPDATE_CONFIG'] && File.exists(ENV['UPDATE_CONFIG'])
          ENV['UPDATE_CONFIG']
        else
          (Dir.glob('{config,.}/updater.config') + Dir.glob('.updater')).first
        end
      end
    end
    
    ROOT = File.dirname(self.config_file)
    
    def initialize(file_or_hash)
      @options = file_or_hash.kind_of?(Hash) ? file_or_hash : load_file(file_or_hash)
      @options[:pid_file] ||= File.join(ROOT,'updater.pid')
      @options[:host] ||= "localhost"
      @logger = Logger.new(@options[:log_file] || STDOUT)
      level = Logger::SEV_LABEL.index(@options[:log_level].upcase) if @options[:log_level]
      @logger.level = level || Logger::WARN 
    end
    
    def start
      @logger.warn "Starting Loop"
      pid = Process.fork do
        _start
      end
      @logger.warn "Rake Successfully started Master Loop at pid #{pid}"
    end
    
    def stop
      Process.kill("TERM",File.read(@options[:pid_file]).to_i)
    end
    
    def client
      
    end
    
    private
    
    def _start
      #set ORM
      require 'updater/orm/datamapper'
      Updater::Update.orm = ORM::DataMapper
      
      #init DataStore
      DataMapper.logger = @logger
      DataMapper.setup(:default, :adapter=>'sqlite3', :database=>'./simulated.db')
      
      #load Models
      
      models = @options[:models] || Dir.glob('./app/models/**/*.rb')
      models.each do |file|
        require file
      end
      
      #establish Connections
      #Unix Socket -- name at @options[:socket]
      if @options[:socket]
        File.unlink @options[:socket] if File.exists? @options[:socket]
        @options[:sockets] ||= []
        @options[:sockets] << UNIXServer.new(@options[:socket])
      end
      
      #UDP potentially unsafe user monitor server for Authenticated Connections (TODO)
      if @options[:udp]
        @options[:sockets] ||= []
        udp = UDPSocket.new
        udp.bind(@options[:host],@options[:udp])
        @options[:sockets] << udp
      end
      
      #TCP Unsafe user monitor server for Authenticated Connections (TODO)
      if @options[:tcp]
        @options[:sockets] ||= []
        @options[:sockets] << TCPServer.new(@options[:host],@options[:tcp])
      end
      
      #Log PID
      File.open(@options[:pid_file],'w') { |f| f.write(Process.pid.to_s)}
      #start Worker
      require 'updater/fork_worker'
      worker_class = ForkWorker
      worker_class.logger = @logger
      worker_class.start(@options)
    end
    
    def load_file(file)
      return {} if file.nil?
      file = File.open(file) if file.kind_of?(String)
      @config_file = File.expand_path(file.path)
      YAML.load(ERB.new(File.read(file)).result(binding)) || {}
    end
  end
end