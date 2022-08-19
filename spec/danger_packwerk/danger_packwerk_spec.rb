require 'spec_helper'

module DangerPackwerk
  RSpec.describe DangerPackwerk do
    describe '#check' do
      let(:packwerk) { dangerfile.packwerk }
      let(:plugin) { packwerk }
      let(:offenses) { [] }
      let(:files_for_packwerk) { ['packs/referencing_pack/some_file.rb'] }
      let(:modified_files) { [write_file('packs/referencing_pack/some_file.rb').to_s] }

      before do
        allow_any_instance_of(Packwerk::Cli).to receive(:execute_command).with(['check', *files_for_packwerk])
        allow_any_instance_of(PackwerkWrapper::OffensesAggregatorFormatter).to receive(:aggregated_offenses).and_return(offenses)
      end

      let(:constant) do
        sorbet_double(Packwerk::ConstantDiscovery::ConstantContext, name: '::PrivateConstant')
      end

      let(:generic_dependency_violation) do
        sorbet_double(
          Packwerk::ReferenceOffense,
          reference: reference,
          violation_type: Packwerk::ViolationType::Dependency,
          message: 'Vanilla message about dependency violations',
          location: Packwerk::Node::Location.new(12, 5)
        )
      end

      let(:generic_privacy_violation) do
        sorbet_double(
          Packwerk::ReferenceOffense,
          reference: reference,
          violation_type: Packwerk::ViolationType::Privacy,
          message: 'Vanilla message about privacy violations',
          location: Packwerk::Node::Location.new(12, 5)
        )
      end

      let(:reference) do
        sorbet_double(
          Packwerk::Reference,
          relative_path: 'packs/referencing_pack/some_file.rb',
          constant: constant
        )
      end

      context 'when there are syntax errors in analyzed files' do
        let(:offenses) { [sorbet_double(Packwerk::Parsers::ParseResult)] }

        it 'exits gracefully' do
          packwerk.check
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          actual_markdowns = dangerfile.status_report[:markdowns]
          expect(actual_markdowns.count).to eq 0
        end
      end

      context 'when the only files modified are ones that packwerk ignores' do
        let(:modified_files) { [write_file('frontend/javascript/some_file.js').to_s] }

        it 'leaves an inline comment helping the user figure out what to do next' do
          expect_any_instance_of(Packwerk::Cli).to_not receive(:execute_command)
          packwerk.check
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          actual_markdowns = dangerfile.status_report[:markdowns]
          expect(actual_markdowns.count).to eq 0
        end
      end

      context 'when there is a new privacy violation when running packwerk check' do
        let(:offenses) { [generic_privacy_violation] }

        it 'leaves an inline comment helping the user figure out what to do next' do
          packwerk.check
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          actual_markdowns = dangerfile.status_report[:markdowns]
          expect(actual_markdowns.count).to eq 1
          actual_markdown = actual_markdowns.first
          expect(actual_markdown.message).to eq 'Vanilla message about privacy violations'
          expect(actual_markdown.line).to eq 12
          expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
          expect(actual_markdown.type).to eq :markdown
        end

        context 'when the failure is in a renamed file' do
          let(:renamed_file) { write_file('packs/referencing_pack/some_file.rb') }
          let(:modified_file) { 'packs/referencing_pack/some_file_with_old_name.rb' }
          let(:modified_files) { [modified_file] }
          let(:renamed_files) { [{ before: modified_file, after: renamed_file.to_s }] }

          it 'leaves an inline comment helping the user figure out what to do next' do
            packwerk.check
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 1
            actual_markdown = actual_markdowns.first
            expect(actual_markdown.message).to eq 'Vanilla message about privacy violations'
            expect(actual_markdown.line).to eq 12
            expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
            expect(actual_markdown.type).to eq :markdown
          end
        end
      end

      context 'when there is a new dependency violation when running packwerk check' do
        let(:offenses) { [generic_dependency_violation] }

        it 'leaves an inline comment helping the user figure out what to do next' do
          packwerk.check
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          actual_markdowns = dangerfile.status_report[:markdowns]
          expect(actual_markdowns.count).to eq 1
          actual_markdown = actual_markdowns.first
          expect(actual_markdown.message).to eq 'Vanilla message about dependency violations'
          expect(actual_markdown.line).to eq 12
          expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
          expect(actual_markdown.type).to eq :markdown
        end
      end

      context 'when there is a new dependency and privacy violation when running packwerk check' do
        let(:offenses) { [generic_dependency_violation, generic_privacy_violation] }

        it 'leaves an inline comment helping the user figure out what to do next' do
          packwerk.check
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          actual_markdowns = dangerfile.status_report[:markdowns]
          expect(actual_markdowns.count).to eq 1
          actual_markdown = actual_markdowns.first
          expect(actual_markdown.message).to eq "Vanilla message about dependency violations\n\nVanilla message about privacy violations"
          expect(actual_markdown.line).to eq 12
          expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
          expect(actual_markdown.type).to eq :markdown
        end
      end

      context 'when there are violations on the same constant' do
        context 'on the same line' do
          let(:reference) do
            sorbet_double(
              Packwerk::Reference,
              relative_path: 'packs/referencing_pack/some_file.rb',
              constant: constant
            )
          end

          let(:offenses) do
            [
              sorbet_double(
                Packwerk::ReferenceOffense,
                reference: reference,
                violation_type: Packwerk::ViolationType::Privacy,
                message: 'Vanilla message about privacy violations',
                location: Packwerk::Node::Location.new(12, 15)
              ),
              sorbet_double(
                Packwerk::ReferenceOffense,
                reference: reference,
                violation_type: Packwerk::ViolationType::Dependency,
                message: 'Vanilla message about dependency violations',
                location: Packwerk::Node::Location.new(12, 15)
              )
            ]
          end

          it 'leaves one comment' do
            packwerk.check
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 1
            actual_markdown = actual_markdowns.first
            expect(actual_markdown.message).to eq "Vanilla message about privacy violations\n\nVanilla message about dependency violations"
            expect(actual_markdown.line).to eq 12
            expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
            expect(actual_markdown.type).to eq :markdown
          end
        end

        context 'within the same file' do
          let(:reference) do
            sorbet_double(
              Packwerk::Reference,
              relative_path: 'packs/referencing_pack/some_file.rb',
              constant: constant
            )
          end

          let(:offenses) do
            [
              sorbet_double(
                Packwerk::ReferenceOffense,
                reference: reference,
                violation_type: Packwerk::ViolationType::Privacy,
                message: 'Vanilla message about privacy violations',
                location: Packwerk::Node::Location.new(12, 5)
              ),
              sorbet_double(
                Packwerk::ReferenceOffense,
                reference: reference,
                violation_type: Packwerk::ViolationType::Privacy,
                message: 'Vanilla message about privacy violations',
                location: Packwerk::Node::Location.new(22, 5)
              )
            ]
          end

          it 'leaves a comment for each violation' do
            packwerk.check
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty

            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 2

            first_actual_markdown = actual_markdowns.first
            expect(first_actual_markdown.message).to eq 'Vanilla message about privacy violations'
            expect(first_actual_markdown.line).to eq 12
            expect(first_actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
            expect(first_actual_markdown.type).to eq :markdown

            second_actual_markdown = actual_markdowns.last
            expect(second_actual_markdown.message).to eq 'Vanilla message about privacy violations'
            expect(second_actual_markdown.line).to eq 22
            expect(second_actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
            expect(second_actual_markdown.type).to eq :markdown
          end
        end

        context 'within the same pack' do
          let(:offenses) do
            [
              sorbet_double(
                Packwerk::ReferenceOffense,
                reference: sorbet_double(
                  Packwerk::Reference,
                  relative_path: 'packs/referencing_pack/some_file.rb',
                  constant: constant
                ),
                violation_type: Packwerk::ViolationType::Privacy,
                message: 'Vanilla message about privacy violations',
                location: Packwerk::Node::Location.new(12, 5)
              ),
              sorbet_double(
                Packwerk::ReferenceOffense,
                reference: sorbet_double(
                  Packwerk::Reference,
                  relative_path: 'packs/referencing_pack/some_other_file.rb',
                  constant: constant
                ),
                violation_type: Packwerk::ViolationType::Privacy,
                message: 'Vanilla message about privacy violations',
                location: Packwerk::Node::Location.new(12, 5)
              )
            ]
          end

          it 'leaves a comment for each violation' do
            packwerk.check
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty

            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 2

            first_actual_markdown = actual_markdowns.first
            expect(first_actual_markdown.message).to eq 'Vanilla message about privacy violations'
            expect(first_actual_markdown.line).to eq 12
            expect(first_actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
            expect(first_actual_markdown.type).to eq :markdown

            second_actual_markdown = actual_markdowns.last
            expect(second_actual_markdown.message).to eq 'Vanilla message about privacy violations'
            expect(second_actual_markdown.line).to eq 12
            expect(second_actual_markdown.file).to eq 'packs/referencing_pack/some_other_file.rb'
            expect(second_actual_markdown.type).to eq :markdown
          end
        end

        context 'across different packs' do
          let(:offenses) do
            [
              sorbet_double(
                Packwerk::ReferenceOffense,
                reference: sorbet_double(
                  Packwerk::Reference,
                  relative_path: 'packs/referencing_pack/some_file.rb',
                  constant: constant
                ),
                violation_type: Packwerk::ViolationType::Privacy,
                message: 'Vanilla message about privacy violations',
                location: Packwerk::Node::Location.new(12, 5)
              ),
              sorbet_double(
                Packwerk::ReferenceOffense,
                reference: sorbet_double(
                  Packwerk::Reference,
                  relative_path: 'packs/another_referencing_pack/some_file.rb',
                  constant: constant
                ),
                violation_type: Packwerk::ViolationType::Privacy,
                message: 'Vanilla message about privacy violations',
                location: Packwerk::Node::Location.new(12, 5)
              )
            ]
          end

          it 'leaves a comment for each violation' do
            packwerk.check
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty

            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 2

            first_actual_markdown = actual_markdowns.first
            expect(first_actual_markdown.message).to eq 'Vanilla message about privacy violations'
            expect(first_actual_markdown.line).to eq 12
            expect(first_actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
            expect(first_actual_markdown.type).to eq :markdown

            second_actual_markdown = actual_markdowns.last
            expect(second_actual_markdown.message).to eq 'Vanilla message about privacy violations'
            expect(second_actual_markdown.line).to eq 12
            expect(second_actual_markdown.file).to eq 'packs/another_referencing_pack/some_file.rb'
            expect(second_actual_markdown.type).to eq :markdown
          end
        end
      end

      context 'when there are 100 new violations when running packwerk check' do
        let(:offenses) do
          100.times.to_a.map do |i|
            sorbet_double(
              Packwerk::ReferenceOffense,
              violation_type: Packwerk::ViolationType::Dependency,
              reference: reference,
              message: 'blah',
              location: Packwerk::Node::Location.new(i, 5)
            )
          end
        end

        context 'the user has not passed in max comments' do
          it 'stops commenting after 15 comments' do
            packwerk.check
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 15
          end
        end

        context 'the user has passed in max comments' do
          it 'stops commenting after the user configured number of comments' do
            packwerk.check(max_comments: 3)
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 3
          end
        end
      end

      context 'the user has passed in a custom offense formatter' do
        let(:offenses) { [generic_dependency_violation, generic_privacy_violation] }

        it 'leaves an inline comment helping the user figure out what to do next' do
          packwerk.check(
            offenses_formatter: ->(offenses) { "There are #{offenses.count} offenses!" }
          )
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          actual_markdowns = dangerfile.status_report[:markdowns]
          expect(actual_markdowns.count).to eq 1
          actual_markdown = actual_markdowns.first
          expect(actual_markdown.message).to eq 'There are 2 offenses!'
          expect(actual_markdown.line).to eq 12
          expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
          expect(actual_markdown.type).to eq :markdown
        end
      end

      context 'the user has passed fail_build' do
        context 'there are offenses' do
          let(:offenses) { [generic_dependency_violation, generic_privacy_violation] }

          it 'fails the build' do
            packwerk.check(fail_build: true)
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to eq(['Packwerk violations were detected! Please resolve them to unblock the build.'])
          end
        end

        context 'the user has passed in a failure message and there are offenses' do
          let(:offenses) { [generic_dependency_violation, generic_privacy_violation] }

          it 'fails the build' do
            packwerk.check(fail_build: true, failure_message: 'Custom error message!')
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to eq(['Custom error message!'])
          end
        end

        context 'there are no offenses' do
          it 'does not fail the build' do
            packwerk.check(fail_build: true)
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
          end
        end
      end

      context 'the user has configured on_failure' do
        let(:offenses) { [generic_dependency_violation, generic_privacy_violation] }

        it 'fails the build' do
          on_failure_called_message = false
          packwerk.check(on_failure: lambda { |offenses|
                                       on_failure_called_message = "`on_failure` called with #{offenses.count} offenses"
                                     })
          expect(on_failure_called_message).to eq '`on_failure` called with 2 offenses'
        end
      end
    end
  end
end
