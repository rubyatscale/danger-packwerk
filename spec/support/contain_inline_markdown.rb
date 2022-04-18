# frozen_string_literal: true

RSpec::Matchers.define(:contain_inline_markdown) do |expected_markdown|
  match do |file_with_markdown|
    binding.pry
  end

  failure_message do |file_with_markdown|
    binding.pry
    # do
  end
end
