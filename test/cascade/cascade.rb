require "rubygems"
require "logger"

ROOT = File.join(File.dirname(__FILE__))
$LOAD_PATH << File.join(File.dirname(__FILE__), '../../lib')

require "dm-core"

require 'updater'
require 'updater/setup'

require File.join(ROOT, 'target.rb')
#TODO setup config for this
DataMapper.setup(:default, :adapter=>'mysql', :database=>'simulate', :user=>'test', :password=>nil, :host=>'localhost')

Updater::Setup.client_setup

Updater::Update.clear_all

err_rpt = Updater::Update.chain(Target,:error_reporter,[:__job__])

Updater::Update.in(1,Target,:method1)
Updater::Update.in(2,Target,:spawner,[],:failure=>err_rpt)

begin
  socket = 'cascade.sock'
  File.unlink socket if File.exists? socket
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
        puts "Opened Socket Connection"
        sockets << server.accept_nonblock
      rescue Errno::EAGAIN, Errno::EINTR
      end
    else
      begin
        loop{ print ready.read_nonblock(16 * 1024)}
      rescue EOFError
        puts "closed scket connection"
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