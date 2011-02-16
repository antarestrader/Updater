require 'logger'
require 'yaml'
require 'socket'
require 'erb'

module Updater
  class Setup
    class << self
      attr_accessor :init
      #start a new server
      def start(options={})
        new(config_file(options), options).start
      end
      
      #stop the server
      def stop(options={})
        new(config_file(options), options).stop
      end
      
      # Used for testing.  Will run through the entire setup process, but
      # not actually start the server, but will log the resulting options.
      def noop(options={})
        new(config_file(options), options).noop
      end
      
      # Connect a client to a server
      def client_setup(options = {})
        new(config_file(options), options).client_setup
      end
      
      # pendeing
      def monitor
        
      end
      
      # Retruns tha locaion of the config file. 
      def config_file(options = {})
        if options[:config_file] && File.exists?(options[:config_file])
          options[:config_file]
        elsif ENV['UPDATE_CONFIG'] && File.exists(ENV['UPDATE_CONFIG'])
          ENV['UPDATE_CONFIG']
        else
          (Dir.glob('{config,.}/updater.config') + Dir.glob('.updater')).first
        end
      end
    end
    
    ROOT = File.dirname(self.config_file || Dir.pwd)
    
    #extended used for clients who want to override parameters
    def initialize(file_or_hash, extended = {})
      @options = file_or_hash.kind_of?(Hash) ? file_or_hash : load_file(file_or_hash)
      @options.merge!(extended)
      @options[:pid_file] ||= File.join(ROOT,'updater.pid')
      @options[:host] ||= "localhost"
      @logger = @options[:logger] || Logger.new(@options[:log_file] || STDOUT)
      level = Logger::SEV_LABEL.index(@options[:log_level].upcase) if @options[:log_level]
      @logger.level = level || Logger::WARN unless @options[:logger] #only set this if we were not handed a logger
      @logger.debug "Debugging output enabled" unless @options[:logger]
      Update.logger = @logger
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
      sleep 1.0
    end
    
    def noop
      @logger.warn "NOOP: will not start service"
      set_orm
      init_orm
      load_models
      client_setup
      @logger.debug @options.inspect
      exit
    end
    
    # The client is responcible for loading classes and making connections.  We will simply setup the Updater spesifics.
    def client_setup
      @logger.info "Updater Client is being initialized..."
      set_orm
      
      Updater::Update.socket = socket_for_client
      
      
      init_orm
      
      #set PID
      if File.exists? @options[:pid_file]
        Updater::Update.pid = File.read(@options[:pid_file]).strip
      end
      
      Updater::Update.config_file = @config_file
      self
    end
    
    def socket_for_client
      if @options[:socket] && File.exists?(@options[:socket])
        @logger.debug "Using UNIX Socket \"#{@options[:socket]}\""
        return UNIXSocket.new(@options[:socket]) if File.exists?(@options[:socket]) && File.stat(@options[:socket]).socket?
      end
      if @options[:udp]
        socket = UDPSocket.new()
        socket.connect(@options[:host],@options[:udp])
        begin
          socket.write '.' #must test UDP sockets
          return socket
        rescue Errno::ECONNREFUSED
        end
      end
      if @options[:tcp]
        begin
          return TCPSocket.new(@options[:host],@options[:tcp])
        rescue Errno::ECONNREFUSED
        end
      end
      if @options[:remote]
        return nil
        raise NotImplimentedError #For future Authenticated Http Rest Server
      end
      return nil
    end
    
    private
    
    def set_orm
      #don't setup twice.  Client setup might call this as part of server setup in which case it is already done
      return false if Updater::Update.orm
      orm = @options[:orm] || "datamapper"
      case orm.to_s.downcase
        when "datamapper"
          require 'updater/orm/datamapper'
          Updater::Update.orm = ORM::DataMapper
        when "mongodb"
          require 'updater/orm/mongo'
          Updater::Update.orm = ORM::Mongo
        when "activerecord"
          require 'updater/orm/activerecord'
          Updater::Update.orm = ORM::ActiveRecord
        else
          require "update/orm/#{orm}"
          Updater::Update.orm = Object.const_get("ORM").const_get(orm.capitalize)
      end
      @logger.info "Data store '#{orm}' selected"
    end
    
    def init_orm
      return false if self.class.init
      self.class.init = true
      default_options = {:adapter=>'sqlite3', :database=>'./default.db'}
      Updater::Update.orm.setup((@options[:database] || @options[:orm_setup] || default_options).merge(:logger=>@logger))
    end
    
    def load_models
      @logger.info "Loading Models..."
      models = @options[:models] || Dir.glob('./app/models/**/*.rb')
      models.each do |file|
        @logger.debug "  - loading file: #{file}"
        begin
          require file
        rescue LoadError
          require File.expand_path(File.join(Dir.pwd,file))
        end
      end
    end
        
    def _start
      #set ORM
      set_orm
      #init DataStore
      init_orm
      #load Models
      load_models
      
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
      file.close if file.kind_of?(IO) && !file.closed?
    end
  end
end
