require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/filters'
require 'rugged'
require 'rubocop'
require 'securerandom'

module Ballercop
  class Autofix
    def initialize(verbose: false)
      @verbose = verbose
      @temp_info_path = "tmp/#{SecureRandom.uuid}.txt"
    end

    def run(unstaged = false)
      ensure_working_dir

      repo = Rugged::Repository.new(@dev_mode ? '../' : '.')
      unstaged = unstaged ? repo.index.diff : nil
      # unstaged = nil # Note: not supporting unstaged files for now
      staged = repo.head.target.diff(repo.index)

      print "Starting ..."
      [staged, unstaged].compact.each do |patches|
        patches.each_patch do |patch|
          file_path = patch.delta.new_file[:path]
          next unless ruby_file?(file_path) && offensive?(file_path, patch)
          print "Errors detected in #{file_path}. Auto fixing ..."

          if patch.delta.status == :added
            RuboCop::CLI.new.run(['-a', corrected_file_path(file_path), "-o#{@temp_info_path}"]) and next
          end

          if patch.delta.status == :modified
            lint_patch(patch, file_path)
          end
          
          print_uncorrected(file_path.split('/').last)
          clean_up
        rescue StandardError => e
          print "#{e.message}, #{e.backtrace}"
        end
      end
      print "Done!"
    end
    
    private

    def print(message)
      return unless @verbose
      p "BALLERCOP: #{message}"
    end

    def offensive?(file_path, patch)
      file_path = corrected_file_path(file_path)
      registry = RuboCop::Cop::Registry.new(RuboCop::Cop::Cop.all)
      config = RuboCop::ConfigStore.new.for(file_path)
      processed_source = RuboCop::ProcessedSource.from_file(file_path, config.target_ruby_version)
      team = RuboCop::Cop::Team.new(registry, config)
      added_lines = []
      patch.each_hunk do |hunk|
        added_lines.concat(hunk.lines.select(&:addition?).map(&:new_lineno))
      end

      team
        .inspect_file(processed_source)
        .sort
        .reject(&:disabled?)
        .any? { |offense| added_lines.include? offense.line }
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

    def lint_patch(patch, file_path)
      file_path = corrected_file_path(file_path)
      parsed_hunks = 1
      temp_file_path = "tmp/#{SecureRandom.uuid}.rb"
      FileUtils.touch(temp_file_path)
      original_content = []
      File.foreach(file_path) { |line| original_content.append(line) }
      last_line_processed = 0

      patch.hunks.each do |hunk|
        print "PARSING HUNK #{parsed_hunks}/#{patch.hunk_count} ..."

        first_addition = hunk.lines.find {|line| line.addition? }
        next unless first_addition.present?

        first_line = first_addition.new_lineno
        last_addition = hunk.lines.reverse.find {|line| line.addition? }
        last_line = last_addition.new_lineno
        temp_file_content = []

        hunk.each_line do |line|
          next unless line.new_lineno >= first_line && line.new_lineno <= last_line
          temp_file_content.append(line.content)
        end

        temp_lint_path = "tmp/#{SecureRandom.uuid}.rb"
        File.write(temp_lint_path, temp_file_content.join, mode: "w")
        RuboCop::CLI.new.run(['-a', temp_lint_path, "-o#{@temp_info_path}"])

        linted_content = []
        temp_content = []
        File.foreach(temp_lint_path) { |line| linted_content.append(line) }
        File.foreach(temp_file_path) { |line| temp_content.append(line) }

        unhunk = last_line_processed < first_line ? original_content[last_line_processed...first_line - 1] : []
        last_line_processed = last_line + 1

        File.write(temp_file_path, (temp_content + unhunk + linted_content).join, mode: "w")
        File.delete(temp_lint_path)

        parsed_hunks += 1
      end

      parsed_content = []
      File.foreach(temp_file_path) { |line| parsed_content.append(line) }

      unparsed_content = []
      File.foreach(file_path) do |line|
        next if $. < last_line_processed
        unparsed_content.append(line)
      end

      File.write(file_path, (parsed_content + unparsed_content).join, mode: "w")
      File.delete(temp_file_path)
    end

    def print_uncorrected(file_name)
      return unless File.exist?(@temp_info_path)
      output = []
      File.foreach(@temp_info_path) { |line| output.append(line) }

      message = output.compact.reject do |line|
        line.squish.blank? || !line.include?(file_name) || line.include?("[Corrected]")
      end

      print message.map(&:squish).join if message.present?
    end

    def clean_up
      File.delete(@temp_info_path) if File.exist?(@temp_info_path)
    end
    
    def ensure_working_dir
      wd = Dir.pwd.split('/').last
      if wd == 'ballercop'
        @dev_mode = true
      elsif wd != 'baller'
        print "ERROR -- Not in Baller root dir" and return
      end
    end
    
    def corrected_file_path(path)
      return '../' + path if @dev_mode
      path
    end
  end
end
