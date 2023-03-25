require 'pry'
require "stringio"

module Ballercop
  class Patch
    def initialize(patch, file_path, relative_file_path, ci = false)
      @patch = patch
      @file_path = file_path
      @relative_file_path = relative_file_path
      @ci = ci
    end
    
    attr_reader :file_path, :fixes_applied, :relative_file_path

    def fix
      if @patch.delta.status == :deleted || !offensive? 
        @fixes_applied = false
        @no_violations = true
        return
      end

      fix_file if @patch.delta.status == :added
      fix_patch if @patch.delta.status == :modified

      @fixes_applied = true
      @no_violations = !offensive?
    end
    
    def offensive?
      offenses.any?
    end
    
    def result_log(logger)
      return logger&.log "✅ No errors 🎉 in #{@file_path}", :success if @no_violations

      logger&.log "❌ #{@file_path}", :info

      if @patch.delta.status == :added
        file_name = @relative_file_path.split('/').last
        output = []
        File.foreach(@output_file) { |line| output.append(line) }
        message = output.compact.reject do |line|
          line.squish.blank? || (!file_name.include?('tmp') && !line.include?(file_name)) || line.include?("[Corrected]")
        end
        message.map { |m| logger&.log "-> #{m.strip}", :warning } if message.present?
        File.delete(@output_file)
      end

      if @patch.delta.status == :modified
        unfixable_offenses.each do |each_offense|
          logger&.log "-> Can not fix #{each_offense.message} at line #{each_offense.line}", :warning
        end
      end
    end

    def offenses(cache = false)
      return @offenses if cache && @offenses.present?
      added_lines = patch_added_lines
      report = rubocop_report
      @offenses = report.offenses.sort
                        .reject(&:disabled?)
                        .select {|offense| added_lines.include?(offense.line) }

      @offenses
    end

    private

    def fix_file
      @output_file = "tmp/#{SecureRandom.uuid}.txt"
      RuboCop::CLI.new.run(['-a', @relative_file_path, "-o#{@output_file}"])
    end
    
    def fix_patch
      offense = fixable_offenses.last

      while offense.present?
        File.write(@relative_file_path, offense.corrector.rewrite)
        offense = fixable_offenses.last
      end
    end

    def rubocop_registry
      @rubocop_registry ||= RuboCop::Cop::Registry.new(RuboCop::Cop::Cop.all) #TODO: grab cops from .rubocop
    end

    def rubocop_team(config)
      @rubocop_team ||= RuboCop::Cop::Team.new(rubocop_registry, config)
    end
    
    def rubocop_config
      @rubocop_config ||= RuboCop::ConfigStore.new.for_file(@relative_file_path)
    end

    def rubocop_report
      config = rubocop_config
      absolute_file_path = config.base_dir_for_path_parameters + '/' + @file_path
      processed_source = RuboCop::ProcessedSource.from_file(absolute_file_path, rubocop_config.target_ruby_version)
      silence_streams(STDERR) do
        return rubocop_team(rubocop_config).investigate(processed_source)
      end
    end

    def fixable_offenses
      offenses.reject {|offense| offense.corrector == nil || offense.status == :unsupported}
    end

    def unfixable_offenses
      offenses(true).select {|offense| offense.corrector == nil || offense.status == :unsupported}
    end

    def patch_added_lines
      added_lines = []
      @patch.each_hunk do |hunk|
        @ci ?
          added_lines.concat(hunk.lines.select(&:deletion?).map(&:old_lineno)) :
          added_lines.concat(hunk.lines.select(&:addition?).map(&:new_lineno))
      end
      added_lines
    end

    def silence_streams(*streams)
      on_hold = streams.collect { |stream| stream.dup }
      streams.each do |stream|
        stream.reopen(RUBY_PLATFORM =~ /mswin/ ? 'NUL:' : '/dev/null')
        stream.sync = true
      end
      yield
    ensure
      streams.each_with_index do |stream, i|
        stream.reopen(on_hold[i])
      end
    end
  end
end