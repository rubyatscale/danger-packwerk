# frozen_string_literal: true

RSpec::Matchers.define(:contain_inline_markdown) do |expected_visualized_message, overridden_filename|
  match do |file_with_markdown|
    # TODO: get this intelligently
    actual_markdowns = dangerfile.status_report[:markdowns]
    @markdown = actual_markdowns.first

    @danger_start_sigil = '==================== DANGER_START'
    @danger_end_sigil = '==================== DANGER_END'
    @match = expected_visualized_message.match(/.*?(#{@danger_start_sigil}\n(.*?)#{@danger_end_sigil}\n).*?/m)
    if @match.nil?
      false
    else
      @expected_message = @match[2]
      @expected_message_including_sigils = @match[1]
      @expected_file_contents = expected_visualized_message.gsub(@expected_message_including_sigils, '').chomp
      @actual_file_contents = File.read(file_with_markdown)
      @expected_line = expected_visualized_message.split("\n").find_index { |line| line == @danger_start_sigil }
      @expected_filename = overridden_filename || file_with_markdown

      [
        @matching_message = @markdown.message == @expected_message,
        @matching_line = @markdown.line == @expected_line,
        @matching_file = @markdown.file == @expected_filename,
        @matching_file_contents = @expected_file_contents == @actual_file_contents
      ].all?
    end
  end

  failure_message do
    if @match.nil?
      <<~FAILURE_MESSAGE
        Could not find matching markdown in #{@expected_filename}. Make sure to use #{@danger_start_sigil} and #{@danger_end_sigil}
        at the beginning of your heredoc to match a markdown message.
      FAILURE_MESSAGE
    elsif !@matching_message
      expect(@markdown.message).to eq @expected_message
    elsif !@matching_line
      expect(@markdown.line).to eq @expected_line
    elsif !@matching_file
      expect(@markdown.file).to eq @expected_filename
    elsif !@matching_file_contents
      expect(@actual_file_contents).to eq @expected_file_contents
    end
  end

  chain :and_nothing_else do
    expect(dangerfile.status_report[:warnings]).to be_empty
    expect(dangerfile.status_report[:errors]).to be_empty
    expect(dangerfile.status_report[:markdowns].count).to eq 1
  end
end

RSpec::Matchers.define(:produce_no_danger_messages) do
  match do |dangerfile|
    expect_dangerfile_to_produce_no_danger_messages dangerfile
  end

  failure_message do |dangerfile|
    expect_dangerfile_to_produce_no_danger_messages dangerfile
  end
end

def expect_dangerfile_to_produce_no_danger_messages(dangerfile)
  expect(dangerfile.status_report[:warnings]).to be_empty
  expect(dangerfile.status_report[:errors]).to be_empty
  expect(dangerfile.status_report[:markdowns]).to be_empty
  expect(dangerfile.status_report[:messages]).to be_empty
end
