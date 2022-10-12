require 'thor'
require 'ballercop'

module Ballercop
  class CLI < Thor
    
    desc "fix", "Safely fixes rubocop issues for staged, changed files"
    option :verbose, aliases: '-v', type: :boolean, desc: "Print warning messages"
    option :unstaged, aliases: '-u', type: :boolean, desc: "Check unstaged changed files"
    option :repo, aliases: '-r', type: :string, desc: "Relative path to repo to apply fixes on. If not specified, command is applied on current directory"
    def fix
      Autofix.new(
        verbose: options[:verbose],
        repo: options[:repo],
      ).run(options[:unstaged])
    end
  end
end
