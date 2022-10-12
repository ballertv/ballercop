module Ballercop
  class Logger
    def initialize(verbose)
      @verbose = verbose
    end

    def log(message)
      return unless @verbose
      p "BALLERCOP: #{message}"      
    end
  end
end