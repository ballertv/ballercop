module Ballercop
  class Logger
    LOG_LEVELS = {
      info: 0,
      warning: 1,
      success: 2,
      error: 3,
    }

    def initialize(log_level = nil)
      @log_level = LOG_LEVELS[log_level || :error]
    end

    def log(message, log_level = :info)
      return unless LOG_LEVELS[log_level] <= @log_level
      case LOG_LEVELS[log_level]
      when LOG_LEVELS[:warning]
        puts "#{message}".yellow
      when LOG_LEVELS[:success]
        puts "#{message}".green
      when LOG_LEVELS[:error]
        puts "#{message}".red
      else
        puts "#{message}"
      end
    end
  end
end