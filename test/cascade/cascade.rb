require "rubygems"
require "logger"
require "yaml"
require "erb"
require "ruby-debug"

ROOT = File.join(File.dirname(__FILE__))
$LOAD_PATH << File.join(File.dirname(__FILE__), '../../lib')

require 'updater'
require 'updater/setup'

require File.expand_path(File.join(ROOT, 'target.rb'))
#TODO setup config for this

cfg_file = ARGV[0] || 'updater.config'
unless File.exists?(cfg_file)
  puts "Cannot find config file \"#{cfg_file}\""
  puts "Usage: ruby cascade.rb [config_file]"
  exit -1
end

File.open(cfg_file) do |file|
  @options = YAML.load(ERB.new(file.read).result(binding)) || {}
end

case @options[:orm].to_sym
  when :datamapper
    require 'dm-core'
    require 'dm-migrations'
    DataMapper.setup(:default, @options[:database])
    DataMapper.auto_migrate!
    Updater::Setup.client_setup @options
  when :mongodb
    Updater::Setup.client_setup @options
    Updater::Update.orm.setup @options[:database].merge(:logger=>Updater::Update.logger)
end
puts "Welcome to the Cascade test"

puts " cleaning up old garbage"
Updater::Update.clear_all

puts "  Adding error reporter"
err_rpt = Updater::Update.chain(Target,:error_reporter,[:__job__])

puts "  Adding the intial cascade jobs"
Updater::Update.in(3,Target,:method1, [], :failure=>err_rpt)
Updater::Update.in(5,Target,:spawner,[],:failure=>err_rpt)

begin
  socket = 'cascade.sock'
  File.unlink socket if File.exists? socket
  puts "Return Message Socket open"
  server = UNIXServer.new(socket)
  sockets = [server]
  @continue = true
  trap(:INT) {|signal| Updater::Update.clear_all; raise RuntimeError}
  while @continue
    ready, _1, _2 = IO.select(sockets, nil, nil)
    next unless ready && ready.first
    ready = ready.first
    if ready.respond_to?(:accept)
      begin
        puts "  Opened socket connection"
        sockets << server.accept_nonblock
      rescue Errno::EAGAIN, Errno::EINTR
      end
    else
      begin
        loop{ print ready.read_nonblock(16 * 1024)}
      rescue EOFError
        puts "  closed socket connection"
        sockets.delete ready
        ready.close
      rescue Errno::EAGAIN, Errno::EINTR
      end
    end
  end
rescue RuntimeError
  puts "Good Bye"
ensure
  File.unlink socket if File.exists? socket
end