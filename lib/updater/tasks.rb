require 'updater'
require 'updater/setup'
namespace :updater do
  desc "Start processing jobs using the settings in updater.config"
  task :start do
    Updater::Setup.start
  end
  
  desc "Stop procedssing jobs"
  task :stop do
    Updater::Setup.stop
  end
  
  desc "Start monitering the Job queue <Planed>"
  task :monitor do
    puts "No Implimentation (yet).  This feature will be comming \"any day now.\""
  end
end