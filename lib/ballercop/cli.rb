require 'thor'
require 'ballercop'

module Ballercop
  class CLI < Thor
    
    desc "fix", "Safely fixes rubocop issues for staged, changed files"
    option :verbose, aliases: '-v', type: :boolean, desc: "Print warning messages"
    option :unstaged, aliases: '-u', type: :boolean, desc: "Check unstaged changed files"
    def fix
      Autofix.new(verbose: options[:verbose]).run(options[:unstaged])
    end
  end
end
