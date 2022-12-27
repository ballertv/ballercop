require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/filters'
require 'rugged'
require 'rubocop'
require 'securerandom'
require 'pry'

require_relative 'patch'
require_relative 'logger'

module Ballercop
  class Autofix
    MAX_RUNS = 2

    def initialize(log: false, log_level: nil, repo: nil)
      @log = log
      @repo = repo
      @logger = Logger.new(log_level&.to_sym) if log
    end

    def run(unstaged = false)
      ensure_working_dir

      runs = 1
      keep_running = true

      log "Starting ...", :info

      until runs > MAX_RUNS || !keep_running
        repo = Rugged::Repository.new(@repo ? @repo : '.')
        staged = !unstaged ? repo.head.target.diff(repo.index) : nil
        unstaged = repo.index.diff
        runs += 1
        keep_running = false
  
        [staged, unstaged].compact.each do |patches|
          patches.each_patch do |patch|
            did_apply_fixes = parse_patch(patch)
            # In some cases when fixes are applied, the fixes break new rule(s) so rerun
            keep_running = true if did_apply_fixes
          rescue StandardError => e
            log "#{e.message}, #{e.backtrace}", :error
          end
        end
      end

      log "Done!", :info
    end
    
    private

    def parse_patch(patch)
      file_path = patch.delta.new_file[:path]
      _patch = Patch.new(patch, corrected_file_path(file_path), @logger)

      return unless ruby_file?(corrected_file_path(file_path)) 
      
      unless  _patch.offensive?
        log "No errors 🎉 in #{file_path}", :info
        return false
      end

      log "Errors detected in #{file_path}. Auto fixing ...", :warning

      if patch.delta.status == :added
        fix_entire_file(corrected_file_path(file_path))
      end

      if patch.delta.status == :modified
        _patch.fix
      end

      true
    end
    
    def fix_entire_file(file_path)
      output_file = "tmp/#{SecureRandom.uuid}.txt"
      RuboCop::CLI.new.run(['-a', file_path, "-o#{output_file}"])
      print_uncorrected(file_path.split('/').last, output_file)
      File.delete(output_file)
    end
    
    def log(message, log_level)
      @logger&.log message, Logger::LOG_LEVELS[log_level]
    end

    def ruby_file?(path)
      rb_file?(path) ||
        rake_file?(path) ||
        gem_file?(path) ||
        ruby_executable?(path)
    end

    def rb_file?(path)
      File.extname(path) == '.rb'
    end

    def rake_file?(path)
      File.extname(path) == '.rake'
    end

    def gem_file?(path)
      File.basename(path) == 'Gemfile' || File.extname(path) == '.gemspec'
    end

    def ruby_executable?(path)
      return false if File.directory?(path)
      line = File.open(path, &:readline)
      line =~ /#!.*ruby/
    rescue ArgumentError, EOFError
      false
    end

    def print_uncorrected(file_name, output_file)
      return unless File.exist?(output_file)
      output = []
      File.foreach(output_file) { |line| output.append(line) }

      message = output.compact.reject do |line|
        line.squish.blank? || (!file_name.include?('tmp') && !line.include?(file_name)) || line.include?("[Corrected]")
      end

      log message.map(&:squish).join, :warning if message.present?
    end

    def ensure_working_dir
      wd = Dir.pwd.split('/').last
      return unless wd == 'ballercop'
      return unless @repo.blank?
      raise StandardError.new("ERROR -- Must run outside of gem. Try --repo=[path_to_repo]")
    end
    
    def corrected_file_path(path)
      return @repo + path if @repo
      path
    end
  end
end
