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
    
    ROOT = File.dirname(self.config_file || Dir.pwd)
    
    #extended used for clients who wnat to override parameters
    def initialize(file_or_hash, extended = {})
      @options = file_or_hash.kind_of?(Hash) ? file_or_hash : load_file(file_or_hash)
      @options.merge(extended)
      @options[:pid_file] ||= File.join(ROOT,'updater.pid')
      @options[:host] ||= "localhost"
      @logger = @options[:logger] || Logger.new(@options[:log_file] || STDOUT)
      level = Logger::SEV_LABEL.index(@options[:log_level].upcase) if @options[:log_level]
      @logger.level = level || Logger::WARN 
    end
    
    def start
      pid = Process.fork do
        _start
      end
      @logger.warn "Successfully started Master Loop at pid #{pid}"
      puts "Job Queue Processor Started at PID: #{pid}"
    end
    
    def stop
      Process.kill("TERM",File.read(@options[:pid_file]).to_i)
    end
    
    # The client is responcible for loading classes and making connections.  We will simply setup the Updater spesifics
    def client_setup
      if @options[:socket]
        Updater::Update.socket = UNIXSocket.new(@options[:socket])
      elsif @options[:udp]
        socket = UNIXSocket.new()
        socket.connect(@options[:host],@options[:udp])
        Updater::Update.socket = socket
      elsif @options[:tcp]
        Updater::Update.socket = TCPSocket.new(@options[:host],@options[:tcp])
      elsif @options[:remote]
        raise NotImplimentedError #For future Authenticated Http Rest Server
      end
      
      #set PID
      if File.exists? @options[:pid_file]
        Updater::Update.pid = File.read(@options[:pid_file]).strip
      end
    end
    
    private
    
    def _start
      #set ORM
      orm = @options[:orm] || "datamapper"
      case orm.downcase
        when "datamapper"
          require 'updater/orm/datamapper'
          Updater::Update.orm = ORM::DataMapper
        when "mongodb"
          require 'updater/orm/mongodb'
          Updater::Update.orm = ORM::MongoDB
        when "activerecord"
          require 'updater/orm/activerecord'
          Updater::Update.orm = ORM::ActiveRecord
        else
          require "update/orm/#{orm}"
          Updater::Update.orm = Object.const_get("ORM").const_get(orm.capitalize)
      end
      #init DataStore
      default_options = {:adapter=>'sqlite3', :database=>'./default.db'}
      Updater::Update.orm.setup((@options[:database] || @options[:orm_setup] || default_options).merge(:logger=>@logger))
      @logger.info "Data store '#{orm}' successfully loaded"
      #load Models
      
      models = @options[:models] || Dir.glob('./app/models/**/*.rb')
      models.each do |file|
        require file
      end
      
      #establish Connections
      @options[:host] ||= 'localhost'
      #Unix Socket -- name at @options[:socket]
      if @options[:socket]
        File.unlink @options[:socket] if File.exists? @options[:socket]
        @options[:sockets] ||= []
        @options[:sockets] << UNIXServer.new(@options[:socket])
        @logger.info "Now listening on UNIX Socket: #{@options[:socket]}"
      end
      
      #UDP potentially unsafe user monitor server for Authenticated Connections (TODO)
      if @options[:udp]
        @options[:sockets] ||= []
        udp = UDPSocket.new
        udp.bind(@options[:host],@options[:udp])
        @options[:sockets] << udp
        @logger.info "Now listening for UDP: #{@options[:host]}:#{@options[:udp]}"
      end
      
      #TCP Unsafe user monitor server for Authenticated Connections (TODO)
      if @options[:tcp]
        @options[:sockets] ||= []
        @options[:sockets] << TCPServer.new(@options[:host],@options[:tcp])
        @logger.info "Now listening for TCP: #{@options[:host]}:#{@options[:tcp]}"
      end
      
      #Log PID
      File.open(@options[:pid_file],'w') { |f| f.write(Process.pid.to_s)}
      
      client_setup
      
      #start Worker
      worker = @options[:worker] || 'fork'  #todo make this line windows safe
      require "updater/#{worker}_worker"
      worker_class = Updater.const_get("#{worker.capitalize}Worker")
      worker_class.logger = @logger
      @logger.info "Using #{worker_class.to_s} to run jobs:"
      worker_class.start(@options)
      File.unlink(@options[:pid_file])
      File.unlink @options[:socket] if @options[:socket] && File.exists?(@options[:socket])
    end
    
    def load_file(file)
      return {} if file.nil?
      file = File.open(file) if file.kind_of?(String)
      @config_file = File.expand_path(file.path)
      YAML.load(ERB.new(file.read).result(binding)) || {}
    ensure
      file.close
    end
  end
end