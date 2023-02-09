require 'thor'
require 'ballercop'

module Ballercop
  class CLI < Thor
    
    desc "fix", "Safely fixes rubocop issues for changed files between provided base branch or 'origin/testflight' by default"
    option :silent, type: :boolean, desc: "Silent log messages"
    option :base, aliases: '-b', desc: "Specify base branch"
    option :unstaged, aliases: '-u', type: :boolean, desc: "Check unstaged changed files only"
    option :staged, aliases: '-s', type: :boolean, desc: "Check staged changed files only"
    option :path, aliases: '-p', type: :string, desc: "Relative path to repo to apply fixes on. If not specified, command is applied on current directory"
    option :files, aliases: '-f', type: :array, desc: "Fix only, space separated, specified file(s). Path to file(s) from repo's root. Note: only files changed, committed or uncommitted, in current branch will be picked up"
    def fix
      Autofix.new(
        silent: options[:silent],
        path: options[:path],
      ).run(
        unstaged: options[:unstaged],
        staged: options[:staged],
        base: options[:base],
        target_files: options[:files]
      )
    end
    
    desc "ci-check", "Check for violations during CI"
    option :path, aliases: '-p', type: :string, desc: "Relative path to repo to apply fixes on. If not specified, command is applied on current directory"
    def ci_check
      Autofix.new(path: options[:path]).ci_check
    end
  end
end
