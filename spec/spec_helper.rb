Dir.glob("./lib/**/*.rb").each{ |f| require f }

class Airbrake
  class << self

    @@exceptions = []
    
    def notify exception
      @@exceptions << exception
    end
  end
end

require "json"
require "rails"

Rails.logger = Logger.new "/dev/null"

ENV["RAILS_ENV"] = "test"