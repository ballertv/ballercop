require 'thor'
require 'ballercop'

module Ballercop
  class CLI < Thor
    
    desc "fix", "Safely fixes rubocop issues for staged, changed files"
    option :log, aliases: '-l', type: :boolean, desc: "Log messages at specified log level"
    option :log_level, type: :string, desc: "Log level. Default: info. [info, warning, error]"
    option :unstaged, aliases: '-u', type: :boolean, desc: "Check unstaged changed files only"
    option :repo, aliases: '-r', type: :string, desc: "Relative path to repo to apply fixes on. If not specified, command is applied on current directory"
    def fix
      Autofix.new(
        log: options[:log],
        log_level: options[:log_level],
        repo: options[:repo],
      ).run(options[:unstaged])
    end
  end
end
