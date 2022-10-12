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
    def initialize(verbose: false, repo: nil)
      @verbose = verbose
      @repo = repo
      @logger = Logger.new(verbose)
    end

    def run(unstaged = false)
      ensure_working_dir

      repo = Rugged::Repository.new(@repo ? @repo : '.')
      staged = repo.head.target.diff(repo.index)
      unstaged = unstaged ? repo.index.diff : nil

      log "Starting ..."

      [staged, unstaged].compact.each do |patches|
        patches.each_patch do |patch|
          parse_patch(patch)
        rescue StandardError => e
          log "#{e.message}, #{e.backtrace}"
        end
      end

      log "Done!"
    end
    
    private

    def parse_patch(patch)
      file_path = patch.delta.new_file[:path]
      _patch = Patch.new(patch, corrected_file_path(file_path), @logger)

      return unless ruby_file?(corrected_file_path(file_path)) 
      
      log "No errors 🎉 in #{file_path}" and return unless  _patch.offensive?

      log "Errors detected in #{file_path}. Auto fixing ..."

      fix_entire_file(corrected_file_path(file_path)) and return if patch.delta.status == :added
      _patch.fix if patch.delta.status == :modified
    end
    
    def fix_entire_file(file_path)
      output_file = "tmp/#{SecureRandom.uuid}.txt"
      RuboCop::CLI.new.run(['-a', file_path, "-o#{output_file}"])
      print_uncorrected(file_path.split('/').last, output_file)
      File.delete(output_file)
    end
    
    def log(message)
      @logger.log message
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

      log message.map(&:squish).join if message.present?
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
