module Ballercop
  class Logger
    LOG_LEVELS = {
      info: 0,
      warning: 1,
      error: 2,
    }

    def initialize(log_level = nil)
      @log_level = LOG_LEVELS[log_level || :info]
    end

    def log(message, log_level = LOG_LEVELS[:info])
      return unless log_level <= @log_level
      case log_level
      when LOG_LEVELS[:warning]
        puts "BALLERCOP: #{message}".yellow
      when LOG_LEVELS[:error]
        puts "BALLERCOP: #{message}".red
      else
        puts "BALLERCOP: #{message}"
      end
    end
  end
end